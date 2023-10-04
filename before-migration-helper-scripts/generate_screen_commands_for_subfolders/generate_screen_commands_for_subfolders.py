# python generate_screen_commands_for_subfolders.py <repo> <subfolder source_jpd

import argparse
import json
import os
import subprocess

def parse_artifactory_response(response_json, subfolder):
    print(f"In parse_artifactory_response subfolder is -> {subfolder}")
    try:
        data = json.loads(response_json)
        uris = [item['uri'] for item in data.get('files', [])]
        folder_list = [subfolder.strip() + uri.strip() for uri in uris]
        print(f"In parse_artifactory_response folder_list is -> {folder_list}")
        return folder_list
    except json.JSONDecodeError:
        print("Error parsing JSON response.")
        return []

def generate_screen_commands(source_jpd, source_repo, target_jpd, target_repo, folder_list):
    screen_commands = []

    for i, root_folder in enumerate(folder_list, start=1):
        subfolder = os.path.join("output", str(i))
        screen_session_name = f"{source_repo}-session{i}"
        screen_command = (
            f"mkdir -p {subfolder}; "
            f"pushd {subfolder}; "
            f"screen -dmS {screen_session_name} bash -c "
            f"'/app/sureshv/sv_test_migrate_n_subfolders_in_parallel.sh "
            f"{source_jpd} {source_repo} {target_jpd} {target_repo} yes {root_folder} yes \\\".conan\\\" 2>&1 | tee {screen_session_name}.log; exit' ; "
            # f"usvartifactory5 {source_repo} jfrogio {target_repo} yes {root_folder} yes \\\".conan\\\" 2>&1 | tee {screen_session_name}.log; exit' ; "
            f"popd"
        )
        screen_commands.append(screen_command)

    return screen_commands




def generate_bash_script(screen_commands, max_jobs, source_repo):
    # Create a string for the array of screen commands
    screen_commands_array = "\n".join([f'"{cmd}"' for cmd in screen_commands])
    
    script = f"""#!/bin/bash

# Execute screen commands with a maximum of {max_jobs} jobs at a time
max_jobs={max_jobs}

# Define an array of screen commands
screen_commands=(
{screen_commands_array}
)

# Execute screen commands as background jobs
i=0
for screen_command in "${{screen_commands[@]}}"; do
    # Start the screen command in the background
    eval "$screen_command" &
    
    # Check the count of running screen sessions
    session_count=$(screen -ls | awk '/\.{source_repo}-/{{print $1}}'| wc -l)


    
    # If the maximum number of jobs is reached, wait for any job to finish
    while ((session_count >= max_jobs)); do
        sleep 1
        session_count=$(screen -ls | awk '/\.{source_repo}-/{{print $1}}'| wc -l)
    done


done

# Wait for all remaining jobs to complete
wait

# Additional cleanup or post-processing commands can go here
"""

    return script



def modify_output_filename(args):
    # Check if the provided --out value is a fully qualified directory path
    if '/' in args.outdir or '\\' in args.outdir:  # Check for '/' (Unix) or '\\' (Windows) path separator
        # Use the provided directory path
        directory = args.outdir
    elif args.outdir == '.':
        # Use the current directory
        directory = ''
    else:
        # Assume it's a filename in the current directory
        directory = ''

    # Create a modified filename with a prefix
    filename = f'{args.source_repo}_generated_screen_cmds.sh'
    return os.path.join(directory, filename)
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate screen commands for Artifactory subfolder migration")
    parser.add_argument("--source_jpd", required=True, help="Source server ID")
    parser.add_argument("--source_repo", required=True, help="Source repository")
    parser.add_argument("--target_jpd", required=True, help="Source server ID")
    parser.add_argument("--target_repo", required=True, help="Source repository")
    parser.add_argument("--subfolder", required=True, help="Subfolder to concatenate to URIs")
    parser.add_argument('--outdir', default=".", help='Output Directory for the geneated screen commands bash script')
   
    args = parser.parse_args()
    
    # Construct and execute the jf rt curl command
    command = [
        "jf", "rt", "curl",
        "-k", "-XGET",
        f"/api/storage/{args.source_repo}/{args.subfolder}?list&deep=1&depth=1&listFolders=1",
        "-L", "--server-id", args.source_jpd
    ]

    try:
        # Execute the command and capture the output
        completed_process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)

        # Parse the JSON response
        response_json = completed_process.stdout
        folder_list = parse_artifactory_response(response_json, args.subfolder)
        
        # Print the screen commands
        screen_commands = generate_screen_commands(args.source_jpd, args.source_repo, args.target_jpd, args.target_repo, folder_list)  # Replace "target_server_id" with your target server ID
        
        # for command in screen_commands:
        #     print(command)
        
        # Generate the Bash script
        max_jobs = 10  # Adjust the maximum number of concurrent jobs as needed
        bash_script = generate_bash_script(screen_commands, max_jobs, args.source_repo)

        # Save the Bash script to a file
        with open(modify_output_filename(args), "w") as script_file:
            script_file.write(bash_script)

        print(f"Generated Bash script: {modify_output_filename(args)}")
    except subprocess.CalledProcessError as e:
        print("Command failed with error:", e.stderr)
