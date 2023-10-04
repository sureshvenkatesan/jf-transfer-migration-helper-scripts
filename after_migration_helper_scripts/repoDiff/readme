# Artifactory Repository Data Comparison

This Python script is designed to compare two repositories in Artifactory and find the artifacts that exist in the source repository but are missing in the target repository. It fetches data from both repositories, compares the URIs, and generates reports of missing artifacts and statistics.
It has same login as the original script in 
https://github.com/jfrog/artifactory-scripts/blob/master/replicationDiff/replicationDiff.sh
and uses the jfrog cli to connect to Artifactory.

## Prerequisites

Before running the script, ensure you have the following prerequisites:

- Python 3.x
- [Artifactory CLI (JFrog CLI)](https://www.jfrog.com/confluence/display/JFROG/JFrog+CLI) installed and configured with server IDs.

## Usage

1. Clone this repository or download the script `repodiff.py` to your local machine.

2. Open a terminal and navigate to the directory where the script is located.

3. Run the script with the following command:

```bash
   python repodiff.py --source-artifactory SOURCE_ARTIFACTORY_ID --target-artifactory TARGET_ARTIFACTORY_ID --source-repo SOURCE_REPOSITORY_NAME --target-repo TARGET_REPOSITORY_NAME
```

The script will fetch data from both repositories, compare URIs, and generate reports in the test/output directory.

## Output

The script generates the following output files:
```
cleanpaths.txt: Contains the URIs of artifacts present in the source repository but missing in the target repository. It also provides statistics on the total size and file extensions.

filepaths_uri.txt: Contains the URIs with the source repository prefix.

filepaths_nometadatafiles.txt: Contains the URIs without unwanted files, such as metadata files.
```

Print all lines from the file that do not match the pattern "-202":
```
awk '!/-202/' filepaths_nometadatafiles.txt
```