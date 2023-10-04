# Artifactory Subfolder Migration

This script helps generate screen commands for migrating subfolders in source Artifactory to target Artifactory . It's designed to work with JFrog Artifactory.

## Usage

You can use this script by providing the following command-line arguments:

```bash
python generate_screen_commands_for_subfolders.py --source_jpd <source_jpd> --source_repo <source_repo> --target_jpd <target_jpd> --target_repo <target_repo> --subfolder <subfolder> [--outdir <outdir>]
```

--source_jpd: Source server ID.
--source_repo: Source repository.
--target_jpd: Target server ID.
--target_repo: Target repository.
--subfolder: Subfolder to concatenate to URIs.
--outdir (optional): Output directory for the generated screen commands Bash script. Default is the current directory.

## Example:
```
python generate_screen_commands_for_subfolders.py \
--source_jpd  usvartifactory5 \
--source_repo merlin \
--target_jpd jfrogio \
--target_repo merlin \
--subfolder folder_with_293_subfolders \
--outdir "/tmp/transfer"
```

## Prerequisites
Before running the script, ensure you have the following:

Python 3.x installed on your system.
JFrog CLI (jf) installed and configured with server IDs

## Script Description
The script performs the following tasks:

- Executes a JFrog CLI (jf) command to fetch subfolder information from Artifactory.
- Parses the JSON response to obtain a list of subfolders.
- Generates screen commands for migrating subfolders in parallel.
- Creates a Bash script that runs these screen commands with a maximum number of concurrent jobs.

## Running the Script
To run the script, follow these steps:

Ensure you meet the prerequisites mentioned above.
Use the provided command-line arguments to execute the script.
The script will generate a Bash script with screen commands for migrating subfolders.
Execute the generated Bash script to initiate the migration process.