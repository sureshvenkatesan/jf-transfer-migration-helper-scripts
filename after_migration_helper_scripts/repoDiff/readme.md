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

Alternative scripts/plugin:
https://git.jfrog.info/projects/PROFS/repos/ps_jfrog_scripts/browse/compare_repos
https://git.jfrog.info/projects/PROFS/repos/jfrog-cli-plugin-compare/browse

---
Note:

The output of
```text
jf rt curl -XGET "/api/storage/APM123-att-repository-gold-local/?list&deep=1&listFolders=0&mdTimestamps=1&statsTimestamps=1&includeRootPath=1"
```
is the following and it already has the last download stats in "artifactory.stats". So use the source_data to get 
the mdTimestamps.artifactory.stats . If the artifact was not downloaded at all the , you could use the 
"lastModified" date. But I chose to use the  default last download stats as  "1900-01-01T00:00:00.000Z." if the 
artifact was never downloaded.
```text

{
  "uri" : "https://proservices.jfrog.io/artifactory/api/storage/APM123-att-repository-gold-local",
  "created" : "2023-11-08T06:02:37.392Z",
  "files" : [ {
    "uri" : "/",
    "size" : -1,
    "lastModified" : "2023-11-01T15:33:50.186Z",
    "folder" : true
  }, {
    "uri" : "/org/jfrog/test/multi/4.0/multi-4.0.pom",
    "size" : 3270,
    "lastModified" : "2023-11-01T15:41:53.497Z",
    "folder" : false,
    "sha1" : "95a4881c266fd1d4679e1008754f45b19cb4da82",
    "sha2" : "6c258cb4cf2a34eed220d3144e4c873eaefd5346f5382f07b7fd5e930bc4d97c",
    "mdTimestamps" : {
      "properties" : "2023-11-01T15:59:51.694Z"
    }
  }, {
    "uri" : "/org/jfrog/test/multi/maven-metadata.xml",
    "size" : 366,
    "lastModified" : "2023-11-01T15:59:51.116Z",
    "folder" : false,
    "sha1" : "8aaf767b2ed90f5614ab7c600dc0dda967f43923",
    "sha2" : "93cd16c957e5cfc44dfaebe7ac54c353ac92eea796f66b45e4bd51d0262582e9",
    "mdTimestamps" : {
      "artifactory.stats" : "2023-11-08T04:08:23.894Z"
    }
}, {
    "uri" : "/org/jfrog/test/multi3/maven-metadata.xml",
    "size" : 367,
    "lastModified" : "2023-11-01T15:59:51.124Z",
    "folder" : false,
    "sha1" : "ffea43340e639fa5c76fe664c2a5ce87ca81f090",
    "sha2" : "c17e801615a49a46db3d6ece16b66060d7e1084bc09ff535764cc470748e969b"
  } ]
}
```