# Artifactory Subfolder Migration

This script is designed to generate a bash script to run screen commands for migrating subfolders  from a source repository to a target repository. It does this by first retrieving a list of subfolders of a given folder from the source repository using the Artifactory REST API, and then generating screen commands to migrate each subfolder in parallel.

## Prerequisites
Before using this script, ensure you have the following prerequisites in place:

Python 3.x installed on your system.

jf CLI: You need the jf CLI tool for interacting with Artifactory. Make sure it's installed and configured correctly.

## Usage

You can use this script by providing the following command-line arguments:

```bash
python generate_screen_commands_for_subfolders.py \
    --source_jpd SOURCE_JPD \
    --source_repo SOURCE_REPO \
    --target_jpd TARGET_JPD \
    --target_repo TARGET_REPO \
    --root_folder ROOT_FOLDER \
    --path_to_migrate_subfolder_script PATH_TO_MIGRATE_SUBFOLDER_SCRIPT \
    --max_subfolders_to_migrate_in_parallel MAX_SUBFOLDERS_TO_MIGRATE_IN_PARALLEL \
    --outdir OUTDIR

```

--source_jpd: Source server ID.
--source_repo: Source repository.
--target_jpd: Target server ID.
--target_repo: Target repository.
--root_folder:  The root folder containing subfolders to migrate.
--path_to_migrate_subfolder_script: (Optional) The path to the [migrate_n_subfolders_in_parallel.sh](../transfer-artifacts-in-sub_folders_in_parallel/migrate_n_subfolders_in_parallel.sh)script used for migrating subfolders.
--outdir (optional): Output directory for the generated screen commands Bash script. Default is the current directory.

## Example:
```
python generate_screen_commands_for_subfolders.py \
--source_jpd  usvartifactory5 \
--source_repo merlin \
--target_jpd jfrogio \
--target_repo merlin \
--root_folder BoseCorp \
--path_to_migrate_subfolder_script "/app/sureshv/migrate_n_subfolders_in_parallel.sh" \
--max_subfolders_to_migrate_in_parallel 18 \
--outdir "/tmp/output"
```
Here BoseCorp is a folder under merlin repository.
In the  "/tmp/output" you will find the  generated script similar to [merlin_generated_screen_cmds.sh](output/merlin_generated_screen_cmds.sh) .

This will generate screen commands to migrate subfolders from the merlin repository in the usvartifactory5 Artifactory server to the merlin repository in the jfrogio Artifactory server. The screen commands will be saved in a Bash script file in the specified output directory.

Make sure to replace the placeholders with your actual values.

## Script Description
The script performs the following tasks:

- Executes a JFrog CLI (jf) command to fetch subfolder information from Artifactory.
- Parses the JSON response to obtain a list of subfolders.
- Generates screen commands for migrating subfolders in parallel. If there are more subfolders you can specify the number of subfolders to migrate in parallel
- Creates a Bash script that runs these screen commands with a maximum number of concurrent jobs.

## Running the Script
To run the script, follow these steps:

- Ensure you meet the prerequisites mentioned above.
- Use the provided command-line arguments to execute the script.
- The python script will generate a Bash script with screen commands for migrating subfolders.
- Execute the generated Bash script to initiate the migration process.