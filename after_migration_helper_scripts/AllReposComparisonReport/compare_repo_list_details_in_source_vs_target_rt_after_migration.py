# python compare_repo_list_details_in_source_vs_target_rt_after_migration.py --source path/to/source/json/file.json \
# --target path/to/target/json/file.json --repos path/to/your/text/file.txt --out path/to/output/comparison.txt

import json
import argparse

# Parse command-line arguments
parser = argparse.ArgumentParser(description='Compare repository details from source and target JSON files.')
parser.add_argument('--source', required=True, help='Path to the source JSON file')
parser.add_argument('--target', required=True, help='Path to the target JSON file')
parser.add_argument('--repos', required=True, help='Path to the text file with repoKeys')
parser.add_argument('--out', required=True, help='Path to the output comparison file')
parser.add_argument('--source_server_id', required=True, help='server-id of source artifactory')
parser.add_argument('--target_server_id', required=True, help='server-id of target artifactory')
args = parser.parse_args()

# Read source JSON file
with open(args.source, 'r') as source_json_file:
    source_data = json.load(source_json_file)

# Read target JSON file
with open(args.target, 'r') as target_json_file:
    target_data = json.load(target_json_file)

# Read list of repoKeys from the text file
with open(args.repos, 'r') as repo_file:
    repo_keys_of_interest = [line.strip() for line in repo_file]

# Extract repository details for each repoKey from source and target
repo_details_of_interest = []
for repo_key in repo_keys_of_interest:
    source_repo_details = next((repo for repo in source_data['repositoriesSummaryList'] if repo['repoKey'] == repo_key), None)
    target_repo_details = next((repo for repo in target_data['repositoriesSummaryList'] if repo['repoKey'] == repo_key), None)

    repo_details_of_interest.append({
        'repoKey': repo_key,
        'source': source_repo_details,
        'target': target_repo_details
    })

# Prepare comparison output for tabular format
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

# Create lists to store repoKeys based on conditions
repos_with_space_difference = []
repos_with_both_differences = []

# Calculate space difference and sort by it in descending order
# repo_details_of_interest.sort(key=lambda repo: repo['source'].get('usedSpaceInBytes', 0) - repo['target'].get('usedSpaceInBytes', 0), reverse=True)
repo_details_of_interest.sort(
    key=lambda repo: (
        repo['source'].get('usedSpaceInBytes', 0) if repo.get('source') is not None else 0
    ) - (
        repo['target'].get('usedSpaceInBytes', 0) if repo.get('target') is not None else 0
    ),
    reverse=True
)

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

# Write comparison output to the specified output file
with open(args.out, 'w') as output_file:
    output_file.write("Tabular Comparison:\n")
    for line in comparison_output_tabular:
        output_file.write(line + '\n')

    output_file.write("\nRepos with Space Difference > 0 ({} repos):\n".format(len(repos_with_space_difference)))
    output_file.write(';'.join(repos_with_space_difference))

    output_file.write("\n\n\nRepos with Both Differences > 0 ({} repos):\n".format(len(repos_with_both_differences)))
    output_file.write("nohup sh -c 'export JFROG_CLI_LOG_LEVEL=DEBUG;JFROG_CLI_ERROR_HANDLING=panic;")
    # output_file.write("jf rt transfer-files ncr ncratleostest --include-repos \"")
    output_file.write(f"jf rt transfer-files {args.source_server_id} {args.target_server_id} --include-repos \"")
    output_file.write(';'.join(repos_with_both_differences))
    output_file.write("\"' &")

    output_file.write("\n\n\nThe last 30 repos with Both Differences > 0:\n")
    output_file.write("nohup sh -c 'export JFROG_CLI_LOG_LEVEL=DEBUG;JFROG_CLI_ERROR_HANDLING=panic;")
    output_file.write(f"jf rt transfer-files {args.source_server_id} {args.target_server_id} --include-repos \"")
    output_file.write(';'.join(repos_with_both_differences[-30:]))
    output_file.write("\"' &")
print(f"Comparison results written to {args.out}")

