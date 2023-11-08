import argparse
import os
import subprocess
import json
from datetime import datetime

def fetch_repository_data(artifactory, repo, output_file):
    command = [
        "jf", "rt", "curl",
        "-X", "GET",
        f"/api/storage/{repo}/?list&deep=1&listFolders=0&mdTimestamps=1&statsTimestamps=1&includeRootPath=1",
        "-L", "--server-id", artifactory
    ]
    print("Executing command:", " ".join(command))
    try:
        with open(output_file, "w") as output:
            subprocess.run(command, stdout=output, stderr=subprocess.PIPE, text=True, check=True)
        print("Command executed successfully.")
    except subprocess.CalledProcessError as e:
        print("Command failed with error:", e.stderr)

def load_json_file(file_path):
    with open(file_path, 'r') as json_file:
        return json.load(json_file)

def write_unique_uris(output_file, unique_uris,total_size):
    file_extension_counts = {}
    with open(output_file, 'w') as uri_file:
        uri_file.write("******************************\n")
        uri_file.write("Files present in the source repository and are missing in the target repository:\n")
        uri_file.write("******************************\n\n")
        for uri in unique_uris:
            uri_file.write(uri + '\n')
            # Generate the count of files sorted by extension
            file_extension = os.path.splitext(uri)[1]
            file_extension_counts[file_extension] = file_extension_counts.get(file_extension, 0) + 1

        # Generate and print the count of files sorted by extension to console
        print("******************************\n")
        print("        FILE STATS\n")
        print("******************************\n\n")
        print("Here is the count of files sorted according to the file extension that are present in the source repository and are missing in the target repository:")
        for extension, count in sorted(file_extension_counts.items()):
            print(f"{extension}: {count}")

        print("Total Unique URIs in source:", len(unique_uris))
        print("Total Size:", total_size)

        # Generate and print the count of files sorted by extension to the output_file
        uri_file.write("******************************\n")
        uri_file.write("        FILE STATS\n")
        uri_file.write("******************************\n\n")
        uri_file.write("Here is the count of files sorted according to the file extension that are present in the source repository and are missing in the target repository:\n")
        uri_file.write(f"Total Unique URIs in source: {len(unique_uris)}\n")
        uri_file.write(f"Total Size: {total_size}\n")

        for extension, count in sorted(file_extension_counts.items()):
            uri_file.write(f"{extension}: {count}\n")


def write_unique_uris_with_repo_prefix(output_file, unique_uris, source_rt_repo_prefix):
    with open(output_file, 'w') as uri_file:
        for uri in unique_uris:
            uri_file.write(source_rt_repo_prefix + uri + '\n')

def write_filepaths_nometadata(unique_uris,filepaths_nometadata_file,):
    with  open(filepaths_nometadata_file, "w") as filepaths_nometadata:
        for uri in unique_uris:
            file_name = uri.strip()
            if any(keyword in file_name for keyword in ["maven-metadata.xml", "Packages.bz2", ".gemspec.rz",
                                                       "Packages.gz", "Release", ".json", "Packages", "by-hash", "filelists.xml.gz", "other.xml.gz", "primary.xml.gz", "repomd.xml", "repomd.xml.asc", "repomd.xml.key"]):
                print(f"Excluded: as keyword in {file_name}")
            else:
                print(f"Writing: {file_name}")
                filepaths_nometadata.write(file_name + '\n')
            # for keyword in ["maven-metadata.xml", "Packages.bz2", ".gemspec.rz",
            #                                             "Packages.gz", "Release", ".json", "Packages", "by-hash", "filelists.xml.gz", "other.xml.gz", "primary.xml.gz", "repomd.xml", "repomd.xml.asc", "repomd.xml.key"]:
            #     if keyword in file_name:
            #         print(f"Excluded: as {keyword} in {file_name}")
            #         break
            # else:
            #     print(f"Writing: {file_name}")
            #     filepaths_nometadata.write(file_name + '\n')

def write_artifact_stats_sort_desc(artifactory, repo, unique_uris, output_file):
    artifact_info = []

    for uri in unique_uris:
        command = [
            "jf", "rt", "curl",
            "-X", "GET",
            f"/api/storage/{repo}/{uri}?stats",
            "-L", "--server-id", artifactory
        ]
        print("Executing command:", " ".join(command))

        try:
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
            print("Command executed successfully.")

            # Parse the JSON response
            response_data = json.loads(result.stdout)

            # Extract relevant information
            last_downloaded = response_data["lastDownloaded"]
            timestamp_utc = datetime.utcfromtimestamp(last_downloaded / 1000.0).strftime('%Y-%m-%d %H:%M:%S UTC')

            # Append to the list
            artifact_info.append((uri, last_downloaded, timestamp_utc))
        except subprocess.CalledProcessError as e:
            print("Command failed with error:", e.stderr)

    # Sort the artifact_info list in descending order of lastDownloaded
    sorted_artifact_info = sorted(artifact_info, key=lambda x: x[1], reverse=True)

    # Write the headers to the output file
    with open(output_file, 'w') as out_file:
        out_file.write("lastDownloaded\tTimestamp (Epoch Millis)\tURI\n")

        # Write the values for each artifact in a single line
        for uri, last_downloaded, timestamp_utc in sorted_artifact_info:
            out_file.write(f"{last_downloaded}\t{timestamp_utc}\t{uri}\n")


def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Check if repo in target Artifactory has all the artifacts from "
                                                 "repo in source Artifactory.")
    parser.add_argument("--source-artifactory", required=True, help="Source Artifactory ID")
    parser.add_argument("--target-artifactory", required=True, help="Target Artifactory ID")
    parser.add_argument("--source-repo", required=True, help="Source repository name")
    parser.add_argument("--target-repo", required=True, help="Target repository name")
    args = parser.parse_args()

    # Create the output directory if it doesn't exist
    output_dir = "test/output"
    os.makedirs(output_dir, exist_ok=True)

    # Fetch data from repositories
    source_log_file = os.path.join(output_dir, "source.log")
    fetch_repository_data(args.source_artifactory, args.source_repo, source_log_file)
    #
    target_log_file = os.path.join(output_dir, "target.log")
    fetch_repository_data(args.target_artifactory, args.target_repo, target_log_file)

    # Load the contents of the JSON files
    source_data = load_json_file(source_log_file)
    target_data = load_json_file(target_log_file)

    # Extract the "uri" values from both source and target files
    source_uris = {item['uri'] for item in source_data['files']}
    target_uris = {item['uri'] for item in target_data['files']}

    # Find the unique URIs and calculate the total size
    unique_uris = source_uris - target_uris
    total_size = sum(item['size'] for item in source_data['files'] if item['uri'] in unique_uris)

    # Write the unique URIs to a file in the output folder
    unique_uris_file = os.path.join(output_dir, "cleanpaths.txt")
    write_unique_uris(unique_uris_file, unique_uris,total_size)

    # Write the unique URIs "with repo prefix" to a file in the output folder
    prefix = f"{args.source_artifactory}/artifactory/{args.source_repo}"
    filepaths_uri_file=os.path.join(output_dir, "filepaths_uri.txt")
    write_unique_uris_with_repo_prefix(filepaths_uri_file,unique_uris,prefix)

    # fetch artifact statistics, extract the relevant information, and sort the lines in descending order of the lastDownloaded timestamp
    # to a file in the output folder
    filepaths_uri_stats_file=os.path.join(output_dir, "filepaths_uri_lastDownloaded_desc.txt")
    write_artifact_stats_sort_desc(args.source_artifactory, args.source_repo, unique_uris, filepaths_uri_stats_file)

    # Filter and write the unique URIs "without unwanted files" , to a file in the output folder
    filepaths_nometadata_file = os.path.join(output_dir, "filepaths_nometadatafiles.txt")
    write_filepaths_nometadata(unique_uris,filepaths_nometadata_file)



if __name__ == "__main__":
    main()
