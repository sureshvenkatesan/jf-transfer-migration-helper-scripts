#!/bin/bash

# Check if at least the first four required parameters are provided
if [ $# -lt 4 ]; then
    echo "Usage: $0 <source-artifactory> <source-repo> <target-repo> <target-artifactory> <transfer yes/no> [root-folder]"
    exit 1
fi

# Assign the input parameters to variables
source_artifactory="$1"
source_repo="$2"
target_artifactory="$3"
target_repo="$4"
TRANSFERONLY="$5"



# Check if the fifth parameter (root-folder) is provided
if [ $# -ge 6 ]; then
    root_folder="$6"
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

# Calculate the total number of folders
total_folders="${#folders_array[@]}"


# Log failed, successful, and all commands to separate files
failed_commands_file="failed_commands.txt"
successful_commands_file="successful_commands.txt"
all_commands_file="all_commands.txt"
skipped_commands_file="skipped_commands.txt"

# touch "$successful_folders_file"

# Function to run the jf rt cp command and log any failures
# The eval command is used to execute the cp_command, and the standard error (error stream) is redirected to standard output (2>&1).
# If the eval command succeeds (i.e., the exit status is zero), it's considered a successful command, and the function logs "Command succeeded."
# If the eval command fails (i.e., the exit status is non-zero), it's considered a failed command, and the function logs "Command failed" along with the exit status and any error message captured from the error stream.

run_migrate_command() {
   
    src_list_command="$1" 
    target_list_command="$2"
    folder_to_migrate="$3"
    folder_position="$4"  # Pass the folder position as an argument
    # Check if the folder has already been successfully copied

    # if grep -q "$folder_to_migrate" "$successful_commands_file"; then
    #     # Note: we just echo it. No need to log it to  "$all_commands_file"
    #     echo "Skipping folder: $folder_to_migrate (already copied)" >> "$skipped_commands_file"
    #     return
    # fi

    # Log what is currently running only if we did not log it earlier.
    # If you stopped the script, no need to log it again , we can always check waht is running using 
    # ps -ef | grep "jf rt cp"
    # if ! grep -q "$folder_to_copy" "$all_commands_file"; then
        echo "Running command: $src_list_command [Progress: $folder_position out of $total_folders folders]" >> "$all_commands_file"
    # fi
    

    # Run the command
    echo $src_list_command
    # Enable debugging
# set -x
    eval "$src_list_command >> a"  
    eval "$target_list_command  >> b"
    # Disable debugging when no longer needed
# set +x
    join -v1  <(sort a) <(sort b) | sed -re 's/,[[:alnum:]]+"$/"/g' |sed 's/"//g' > c
    
    if [ "${TRANSFERONLY}" = "no" ]; then
        echo "-------------------------------------------------"
        echo "Files diff from source $source_artifactory - Repo [$source_repo]"
        echo "-------------------------------------------------"
        cat -b c
   elif [ "${TRANSFERONLY}" = "yes" ]; then
    while IFS= read -r line
    do
        echo "jf rt dl \"$source_repo/$line\" . --server-id $source_artifactory ; jf rt u \"$line\" \"$target_repo/$line\" --server-id $target_artifactory ; rm -rf \"$line\" "
        #jf rt dl \"$1/$line\" . --server-id $SOURCE_ID ; jf rt u \"$line\" \"$1/$line\" --server-id $TARGET_ID ; rm -f \"$line\"
    done < "c"
    else 
    echo "Wrong 5th Parameter, 5th parameter value should be yes or no"
    fi 
rm -f a b c
}





# Loop through the folders and generate the jf rt cp commands
for folder_position in "${!folders_array[@]}"; do
    folder="${folders_array[$folder_position]}"
    #Remove the leading slash i.e if folder is "/abc" it becomes "abc"
    folder="${folder#/}"
    # Check if the folder name is ".conan" and skip it as it will be generated
    if [ "$folder" = ".conan" ]; then
        continue  # Skip this iteration of the loop
    fi


    src_list_command=""
    target_list_command=""

    jq_sed_command2="| jq '.results[]|(.path +\"/\"+ .name+\",\"+(.sha256|tostring))'  | sed  's/\.\///'"
    if [ -z "$root_folder" ]; then
       folder_to_migrate="$folder/*"
    else
        folder_to_migrate="$root_folder/$folder/*"
    fi

    src_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $source_artifactory --insecure --data 'items.find({\"repo\":  {\"\$eq\":\"$source_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate\"},        \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"
    

    target_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $target_artifactory --insecure \
    --data 'items.find({\"repo\":  {\"\$eq\":\"$target_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate\"},\
        \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"

        # Concatenate the two commands 
    src_list_command="$src_command1 $jq_sed_command2"
    target_list_command="$target_command1 $jq_sed_command2"
    
#     echo $src_list_command
#    echo $target_list_command

    #Call the migrate command without the trailing * in $folder_to_migrate
    folder_to_migrate="${folder_to_migrate/%\*/}"  # Remove the trailing "*"
    run_migrate_command "$src_list_command" "$target_list_command" "$folder_to_migrate" "$((folder_position + 1))"
    
    # Limit to 5 parallel commands
    # if [[ $(jobs | wc -l) -ge 5 ]]; then
    #     wait -n
    # fi
done #| parallel -j 8

# Wait for any remaining background jobs to finish
# wait
