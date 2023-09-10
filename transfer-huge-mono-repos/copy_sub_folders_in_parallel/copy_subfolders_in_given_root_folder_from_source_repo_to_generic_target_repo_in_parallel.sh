#!/bin/bash

# Check if at least the first four required parameters are provided
if [ $# -lt 4 ]; then
    echo "Usage: $0 <source-artifactory> <source-repo> <target-repo> <target-artifactory> [root-folder]"
    exit 1
fi

# Assign the input parameters to variables
source_artifactory="$1"
source_repo="$2"
target_artifactory="$3"
target_repo="$4"

# Check if the fifth parameter (root-folder) is provided
if [ $# -ge 5 ]; then
    root_folder="$5"
else
    root_folder=""
fi

# Run the jf rt curl command and capture the output into a variable
if [ -z "$root_folder" ]; then
    output=$(jf rt curl -k -XGET "/api/storage/$source_repo?list&deep=1&depth=1&listFolders=1" --server-id $source_artifactory)
else
    output=$(jf rt curl -k -XGET "/api/storage/$source_repo/$root_folder?list&deep=1&depth=1&listFolders=1" --server-id $source_artifactory)
fi

# Parse the JSON output using jq and get the "uri" values for folders
folders=$(echo "$output" | jq -r '.files[] | select(.folder) | .uri')

# Split folders into an array
IFS=$'\n' read -rd '' -a folders_array <<< "$folders"

# Log failed, successful, and all commands to separate files
failed_commands_file="failed_commands.txt"
successful_commands_file="successful_commands.txt"
all_commands_file="all_commands.txt"

# Function to run the jf rt cp command and log any failures
# The eval command is used to execute the cp_command, and the standard error (error stream) is redirected to standard output (2>&1).
# If the eval command succeeds (i.e., the exit status is zero), it's considered a successful command, and the function logs "Command succeeded."
# If the eval command fails (i.e., the exit status is non-zero), it's considered a failed command, and the function logs "Command failed" along with the exit status and any error message captured from the error stream.

run_cp_command() {
    cp_command="$1"
    echo "Running command: $cp_command" >> "$all_commands_file"
    
    # Run the command and capture the exit status and error output
    #error_output=$(eval "$cp_command" 2>&1 >/dev/tty)
    #error_output=$({ eval "$cp_command" 2>&1 >&3; } 3>&1)
    # Run the command
    $cp_command
    
    # Capture the exit status
    error_code=$?

    if [ $error_code -eq 0 ]; then
        echo "Command succeeded: $cp_command (Exit Status: $error_code)" >> "$successful_commands_file"
    else
        echo "Command failed: $cp_command (Exit Status: $error_code)" >> "$failed_commands_file"
        #echo "Error Message: $error_output" >> "$failed_commands_file"
    fi
}



# Loop through the folders and generate the jf rt cp commands
for folder in "${folders_array[@]}"; do
    if [ -z "$root_folder" ]; then
        cp_command="jf rt cp $source_repo$folder/ $target_repo/ --flat=false --threads=8 --dry-run=false --server-id $target_artifactory"
    else
        cp_command="jf rt cp $source_repo/$root_folder$folder/ $target_repo/ --flat=false --threads=8 --dry-run=false --server-id $target_artifactory"
    fi

    run_cp_command "$cp_command" &
    
    # Limit to 5 parallel commands
    if [[ $(jobs | wc -l) -ge 5 ]]; then
        wait -n
    fi
done

# Wait for any remaining background jobs to finish
wait
