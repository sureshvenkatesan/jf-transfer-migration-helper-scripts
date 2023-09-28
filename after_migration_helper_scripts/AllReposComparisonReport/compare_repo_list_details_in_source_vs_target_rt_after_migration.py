"""
Usage:
python compare_repo_list_details_in_source_vs_target_rt_after_migration.py \
    --source /Users/sureshv/Documents/From_Customer/ncr/group1/ncr_storageinfo.json \
    --target /Users/sureshv/Documents/From_Customer/ncr/group2/ncratleostest_storageinfo.json \
    --repos /Users/sureshv/Documents/From_Customer/ncr/group2/group2_found_in_all_local_repos_in_ncr.txt \
    --out /Users/sureshv/Documents/From_Customer/ncr/group2/comparison/2.txt \
    --source_server_id ncr \
    --target_server_id ncratleostest \
    --total_repos_customer_will_migrate 30 \
    --num_buckets_for_jfrog_ps_to_migrate 3 \
    --repo_threshold_in_gb 1000 \
    --print_alternative_transfer
"""

import json
import argparse
import os

def parse_args():
    parser = argparse.ArgumentParser(description='Compare repository details from source and target JSON files.')
    parser.add_argument('--source', required=True, help='Path to the source JSON file')
    parser.add_argument('--target', required=True, help='Path to the target JSON file')
    parser.add_argument('--repos', required=True, help='Path to the text file with repoKeys which customer wants to migrate')
    parser.add_argument('--out', required=True, help='Path to the output comparison file')
    parser.add_argument('--source_server_id', required=True, help='server-id of source artifactory')
    parser.add_argument('--target_server_id', required=True, help='server-id of target artifactory')
    parser.add_argument('--total_repos_customer_will_migrate', type=int, default=30, help='How many repos customer is responsible to migrate')
    parser.add_argument('--num_buckets_for_jfrog_ps_to_migrate', type=int, default=2, help='How many repo buckets Jfrog PS is responsible to migrate')
    parser.add_argument('--repo_threshold_in_gb', type=int, default=500, help='Threshold in GB for source repos to generate alternate migrate commands')
    parser.add_argument('--print_alternative_transfer', action='store_true', default=False, help='Print alternative transfer method for big source repos')

    return parser.parse_args()

def read_json_file(file_path):
    with open(file_path, 'r') as json_file:
        return json.load(json_file)

def read_repo_keys(repo_keys_file):
    with open(repo_keys_file, 'r') as repo_file:
        return [line.strip() for line in repo_file]

def extract_repo_details(repo_keys, source_data, target_data):
    repo_details_of_interest = []
    for repo_key in repo_keys:
        source_repo_details = next((repo for repo in source_data['repositoriesSummaryList'] if repo['repoKey'] == repo_key), None)
        target_repo_details = next((repo for repo in target_data['repositoriesSummaryList'] if repo['repoKey'] == repo_key), None)

        repo_details_of_interest.append({
            'repoKey': repo_key,
            'source': source_repo_details,
            'target': target_repo_details
        })
    return repo_details_of_interest

def generate_comparison_output(repo_details_of_interest, args):
    comparison_output_tabular = []
    comparison_output_tabular.append("{:<64} {:<15} {:<15} {:<15} {:<15} {:<20} {:<20} {:<25} {:<20}".format("Repo Key",
                                                                                                             "Source "
                                                                                                             "repoType",
                                                                                                             "Target "
                                                                                                             "repoType",
                                                                                                             "Source "
                                                                                                             "filesCount",
                                                                                                             "Target filesCount",
                                                                                                             "Used Space (Source)",
                                                                                                             "Used Space (Target)",
                                                                                                             "SpaceInBytes Difference",
                                                                                                             "Remaining Transfer %"))
    comparison_output_tabular.append("="*200)

    repos_with_space_difference = []
    repos_with_both_differences = []

    # Calculate space difference and sort by it in descending order
    repo_details_of_interest.sort(
        key=lambda repo: (
            repo['source'].get('usedSpaceInBytes', 0) if repo.get('source') is not None else 0
        ) - (
            repo['target'].get('usedSpaceInBytes', 0) if repo.get('target') is not None else 0
        ),
        reverse=True
    )

    # Initialize a list to track big source repos
    big_source_repos = []
    # Define the threshold in bytes (1 GB = 1024 * 1024 * 1024 bytes)
    threshold_bytes = args.repo_threshold_in_gb * 1024 * 1024 * 1024

    for repo_details in repo_details_of_interest:
        repo_key = repo_details['repoKey']
        source_details = repo_details['source'] if repo_details['source'] else {}
        target_details = repo_details['target'] if repo_details['target'] else {}

        source_files_count = source_details.get('filesCount', 0)
        target_files_count = target_details.get('filesCount', 0)

        source_space_in_bytes = source_details.get('usedSpaceInBytes', 0)
        target_space_in_bytes = target_details.get('usedSpaceInBytes', 0)

        space_difference = source_space_in_bytes - target_space_in_bytes

        if space_difference > 0:
            repos_with_space_difference.append(repo_key)
            if source_files_count - target_files_count > 0:
                repos_with_both_differences.append(repo_key)

        # Check if source_space_in_bytes exceeds the threshold
        if source_space_in_bytes > threshold_bytes:
            big_source_repos.append(repo_key)
            
        source_repo_type = source_details.get('repoType', 'N/A')
        target_repo_type = target_details.get('repoType', 'N/A')

        source_used_space = source_details.get('usedSpace', 'N/A')
        target_used_space = target_details.get('usedSpace', 'N/A')

        transfer_percentage = (space_difference / source_space_in_bytes) * 100 if source_space_in_bytes != 0 else 0

        comparison_output_tabular.append("{:<64} {:<15} {:<15} {:<15} {:<15} {:<20} {:<20} {:<25} {:<20.2f}".format(repo_key,
                                                                                                                    source_repo_type,
                                                                                                                    target_repo_type,
                                                                                                                    source_files_count,
                                                                                                                    target_files_count,
                                                                                                                    source_used_space,
                                                                                                                    target_used_space,
                                                                                                                    space_difference,
                                                                                                                    transfer_percentage))

    # sort the repo lists
    repos_with_space_difference.sort()
    repos_with_both_differences.sort()
    big_source_repos.sort()

    return comparison_output_tabular, repos_with_space_difference, repos_with_both_differences, big_source_repos

def print_alternative_transfer_method(output_file,big_source_repos, source_server_id, target_server_id):
    if not big_source_repos:
        output_file.write("\n\n\nNo big source repositories to transfer.\n")
        return

    output_file.write("\n\n\nAlternative Transfer Method for Big Source Repositories:\n\n")
    # for repo in big_source_repos:
    #     output_file.write(f"\nTransfer {repo} from {source_server_id} to {target_server_id}")
    screen_commands = generate_screen_commands(big_source_repos, source_server_id, target_server_id)

    # Write screen commands to a file
    # This code will generate screen commands for each repository in big_source_repos, create subfolders for each screen session, 
    # and write the screen commands to a file. The session names (upload-session1, upload-session2, etc.) are based on the index of the repository in the list.

    # with open("screen_commands.txt", "w") as output_file:
    for command in screen_commands:
        output_file.write(command + "\n")







def bucket_repositories(repos_to_bucket, args):
    # Calculate the number of buckets
    num_buckets = min(args.num_buckets_for_jfrog_ps_to_migrate, len(repos_to_bucket))

    repos_per_bucket = len(repos_to_bucket) // num_buckets
    buckets = [[] for _ in range(num_buckets)]

    remainder = len(repos_to_bucket) % num_buckets

    # Initialize the index and offset for distributing items
    index = 0
    # offset = 0

    # Loop through the repos and distribute them into buckets
    for bucket_index in range(num_buckets):
        bucket_size = repos_per_bucket + 1 if bucket_index < remainder else repos_per_bucket
        buckets[bucket_index].extend(repos_to_bucket[index:index + bucket_size])
        index += bucket_size
    
    return buckets

def write_output(output_file, comparison_output_tabular, repos_with_space_difference, repos_with_both_differences, big_source_repos, args, buckets):
    output_file.write("Tabular Comparison:\n")
    for line in comparison_output_tabular:
        output_file.write(line + '\n')

    output_file.write("\nRepos with 'usedSpaceInBytes' Difference > 0 ({} repos):\n".format(len(repos_with_space_difference)))
    output_file.write(';'.join(repos_with_space_difference))

    output_file.write("\n\n\nRepos with Both 'usedSpaceInBytes' and filesCount Differences > 0 ({} repos):\n".format(len(repos_with_both_differences)))
    output_file.write("nohup sh -c 'export JFROG_CLI_LOG_LEVEL=DEBUG;JFROG_CLI_ERROR_HANDLING=panic;")
    output_file.write(f"jf rt transfer-files {args.source_server_id} {args.target_server_id} --include-repos \"")
    output_file.write(';'.join(repos_with_both_differences))
    output_file.write("\"' &")

    if args.print_alternative_transfer:
        print_alternative_transfer_method(output_file, big_source_repos, args.source_server_id, args.target_server_id)

    output_file.write("\n\n\nJFrog PS to migrate below repos with Both Differences > 0:\n")
    if not buckets:
        print("Warning: There are no repos for JFrog PS to migrate.")
    else:
        for i, bucket in enumerate(buckets, start=0):
            output_file.write(f"\n\n{len(bucket)} repos : \n")
            output_file.write("nohup sh -c 'export JFROG_CLI_LOG_LEVEL=DEBUG;JFROG_CLI_ERROR_HANDLING=panic;")
            output_file.write(f"jf rt transfer-files {args.source_server_id} {args.target_server_id} --include-repos \"")
            output_file.write(';'.join(bucket))
            output_file.write("\"' &")

    output_file.write(f"\n\n\nCustomer responsible to migrate below {args.total_repos_customer_will_migrate} repos with Both Differences > 0:\n")
    output_file.write("nohup sh -c 'export JFROG_CLI_LOG_LEVEL=DEBUG;JFROG_CLI_ERROR_HANDLING=panic;")
    output_file.write(f"jf rt transfer-files {args.source_server_id} {args.target_server_id} --include-repos \"")
    output_file.write(';'.join(repos_with_both_differences[-args.total_repos_customer_will_migrate:]))
    output_file.write("\"' &")

def subtract_lists(list1, list2):
    return [item for item in list1 if item not in list2]

def generate_screen_commands(big_source_repos, source_server_id, target_server_id):
    screen_commands = []

    # Determine the number of subfolders based on the number of items in big_source_repos
    num_subfolders = len(big_source_repos)

    # Create subfolders if they don't exist
    for i in range(1, num_subfolders + 1):
        subfolder = os.path.join("output", str(i))
        os.makedirs(subfolder, exist_ok=True)

    for i, repo in enumerate(big_source_repos, start=1):
        subfolder = os.path.join("output", str(i))
        screen_session_name = f"upload-session{i}"
        screen_command = (
            f"cd {subfolder}\n"
            f"screen -dmS {screen_session_name} bash -c './sv_test_migrate_n_subfolders_in_parallel.sh "
            f"{source_server_id} {repo} {target_server_id} {repo} yes \".conan\" 2>&1 | tee {screen_session_name}.log; exec bash'"
            f"\ncd ../..\n"
        )
        screen_commands.append(screen_command)

    return screen_commands

def main():
    args = parse_args()

    source_data = read_json_file(args.source)
    target_data = read_json_file(args.target)
    repo_keys = read_repo_keys(args.repos)

    repo_details_of_interest = extract_repo_details(repo_keys, source_data, target_data)
    comparison_output_tabular, repos_with_space_difference, repos_with_both_differences , big_source_repos = generate_comparison_output(repo_details_of_interest, args)

    # ... (rest of the code for bucketing and writing output)
    if args.print_alternative_transfer:

        # Subtract big_source_repos from repos_with_both_differences to get small_repos_with_both_differences
        small_repos_with_both_differences = subtract_lists(repos_with_both_differences, big_source_repos)
        small_repos_with_both_differences.sort()
        
        # Exclude the last n repos based on the --total_repos_customer_will_migrate argument
        repos_to_bucket = small_repos_with_both_differences[:-args.total_repos_customer_will_migrate]

        # Bucket the repositories
        buckets = bucket_repositories(repos_to_bucket, args)

        # Write the output
        with open(args.out, 'w') as output_file:
            write_output(output_file, comparison_output_tabular, repos_with_space_difference, small_repos_with_both_differences, big_source_repos, args, buckets)

    else:
        # Exclude the last n repos based on the --total_repos_customer_will_migrate argument
        repos_to_bucket = repos_with_both_differences[:-args.total_repos_customer_will_migrate]

        # Bucket the repositories
        buckets = bucket_repositories(repos_to_bucket, args)

        # Write the output
        with open(args.out, 'w') as output_file:
            write_output(output_file, comparison_output_tabular, repos_with_space_difference, repos_with_both_differences, big_source_repos, args, buckets)

    print(f"Comparison results written to {args.out}")

if __name__ == "__main__":
    main()
