#!/bin/bash

# ./sv_test_migrate_n_subfolders_in_parallel.sh usvartifactory5 liquid jfrogio liquid  no  
# Check if at least the first four required parameters are provided
if [ $# -lt 4 ]; then
    echo "Usage: $0 <source-artifactory> <source-repo> <target-repo> <target-artifactory> <transfer yes/no> [semicolon separted exclude_folders] [root-folder]"
    exit 1
fi

# Create an "output" folder and run the script inside it
mkdir -p output
cd output

# Assign the input parameters to variables
source_artifactory="$1"
source_repo="$2"
target_artifactory="$3"
target_repo="$4"
TRANSFERONLY="$5"
EXCLUDE_FOLDERS=";.conan;$6;"
# jq_sed_command="jq '.results[]|(.path +\"/\"+ .name+\",\"+(.sha256|tostring))'  | sed  's/\.\///'"

# Counter to limit parallel execution
#parallel_count=0

# Log failed, successful, and all commands to separate files
failed_commands_file="failed_commands.txt"
successful_commands_file="successful_commands.txt"
all_commands_file="all_commands.txt"


# Function to execute the migration commands for a single file
execute_artifact_migration() {
    local folder_position="$1"
    local source_repo="$2"
    local line="$3"
    local source_artifactory="$4"
    local target_repo="$5"
    local target_artifactory="$6"
    local escaped_modified_json="$7"
    # Save the current directory to a variable
    local current_dir="$(pwd)"



    # Check if the length of the trimmed $escaped_modified_json is greater than 1 , i.e artifact has a property
    if [ ${#escaped_modified_json} -gt 1 ]; then
        # Execute the commands for a single artifact 
        cd "$folder_position" && \
        jf rt dl "$source_repo/$line" . --threads=8 --server-id "$source_artifactory" && \
        jf rt u "$line" "$target_repo/$line" --threads=8 --server-id "$target_artifactory" && \
        jf rt curl -k -sL -XPATCH -H "Content-Type: application/json" "/api/metadata/$target_repo/$line?atomicProperties=1" \
         --server-id "$target_artifactory" -d "$escaped_modified_json" && \
        #echo "In $(pwd). Now removing $line ----------------->" && \
        rm -rf "$line" && \
        cd "$current_dir" # Return to the saved directory i.e "$OLDPWD"
        if [ $? -ne 0 ]; then
            echo "At least one command failed for: $source_repo/$line" >> "$current_dir/$failed_commands_file"
        else
            echo "All commands succeeded for: $source_repo/$line" >> "$current_dir/$successful_commands_file"
        fi
    else
        # Execute the commands for a single artifact 
        cd "$folder_position" && \
        jf rt dl "$source_repo/$line" . --threads=8 --server-id "$source_artifactory" && \
        jf rt u "$line" "$target_repo/$line" --threads=8 --server-id "$target_artifactory" && \
        #echo "In $(pwd). Now removing $line ----------------->" && \
        rm -rf "$line" && \
        cd "$current_dir" # Return to the saved directory i.e "$OLDPWD"
        if [ $? -ne 0 ]; then
            echo "At least one command failed for: $source_repo/$line" >> "$current_dir/$failed_commands_file"
        else
            echo "All commands succeeded for: $source_repo/$line" >> "$current_dir/$successful_commands_file"
        fi
    fi
}


run_migrate_command() {
   
    local src_list_command="$1" 
    local target_list_command="$2"
    local folder_to_migrate="$3"
    local folder_position="$4"  # Pass the folder position as an argument
    local sibling_folder_count="$5"
    local top_or_inner="$6"

    mkdir -p $folder_position
  

    context=$(echo "$folder_to_migrate" | tr '/' '_' | tr '.' '_')
    context="${context}_${top_or_inner}"
    # Modify the file names for files "a," "b," and "c"

    a="$folder_position/src_list_$source_repo_$context"
    b="$folder_position/target_list_$source_repo_$context"
    c="$folder_position/migrate_list_$source_repo_$context"


    # Log what is currently running
    echo "Running commands: $src_list_command [Progress: $folder_position out of $sibling_folder_count sub folders] $target_list_command" >> "$all_commands_file"

    

    # Run the command
    # echo "$src_list_command"
    # echo "$target_list_command"
    # Enable debugging
    #  set -x

    src_output=$(eval "$src_list_command")
    src_exit_status=$?

    if [ $src_exit_status -ne 0 ]; then
        echo "Error: Command failed for folder: $folder_to_migrate - Run Command: $src_list_command"
        echo "Error: Command failed for folder: $folder_to_migrate - Run Command: $src_list_command" >> "$failed_commands_file"
    fi

    target_output=$(eval "$target_list_command")
    target_exit_status=$?

    if [ $target_exit_status -ne 0 ]; then
        echo "Error: Command failed for folder: $folder_to_migrate - Run Command: $target_list_command"
        echo "Error: Command failed for folder: $folder_to_migrate - Run Command: $target_list_command" >> "$failed_commands_file"
    fi
    # Disable debugging when no longer needed
    #  set +x
    if [ $src_exit_status -eq 0 ] && [ $target_exit_status -eq 0 ]; then
        echo $src_output > "${a}.tmp"
        echo "In run_migrate_command - 1 - b4 calling jq" 
        # cat "${a}.tmp"
        cat "${a}.tmp" | jq '.results[] | select(has("path") and .path != null and has("name") and .name != null and has("sha256") and .sha256 != null) | (.path + "/" + .name + "," + (.sha256|tostring))' | sed 's/\.\///' | tr ' ' '\n' > "$a"
        echo "In run_migrate_command - 2 - after calling jq" 

        echo "$target_output" > "${b}.tmp"
        echo "In run_migrate_command - 3 - b4 calling jq" 
        # cat "${b}.tmp"
        cat "${b}.tmp" | jq '.results[] | select(has("path") and .path != null and has("name") and .name != null and has("sha256") and .sha256 != null) | (.path + "/" + .name + "," + (.sha256|tostring))' | sed  's/\.\///' | tr ' ' '\n' > "$b"
        echo "In run_migrate_command - 4 - after calling jq" 

        #join -v1  <(sort "$a") <(sort "$b") | sed -re 's/,[[:alnum:]]+"$/"/g' | sed 's/"//g'| sed  '/\(index\.json\|\.timestamp\|conanmanifest\.txt\)$/d' > "$c"
        # join -v1  <(sort "$a") <(sort "$b") | sed -E -e 's/,[[:alnum:]]+"$/"/g' -e 's/"//g' -e '/(index\.json|\.timestamp|conanmanifest\.txt)$/d' > "$c"
        echo "In $(pwd) comparing - $a    to   $b"
        join -v1  <(sort "$a") <(sort "$b") | sed -E -e 's/,[[:alnum:]]+"$/"/g' -e 's/"//g'  > "$c"
        # Check if the file exists and is not empty
        if [ -s "$c" ]; then
            if [ "${TRANSFERONLY}" = "no" ]; then
                echo "-------------------------------------------------"
                echo "Files diff in $c for source $source_artifactory - Repo [$source_repo]/$folder_to_migrate -  [Progress: $folder_position out of $sibling_folder_count folders]"
                echo "-------------------------------------------------"

                cat -b "$c"
            elif [ "${TRANSFERONLY}" = "yes" ]; then
                while IFS= read -r line
                do

                    # Does the artifact have properties
                    get_item_properties_cmd="jf rt  curl -s -k -XGET \"/api/storage/$source_repo/$line?properties\" --server-id $source_artifactory"
                    # echo $get_item_properties_cmd
                    prop_output=$(eval "$get_item_properties_cmd")
                    prop_exit_status=$?
                    # echo $prop_output

                    if [ $prop_exit_status -ne 0 ]; then
                        echo "Error: Command failed for folder: $folder_to_migrate - Run Command: $get_item_properties_cmd"
                        echo "Error: Command failed for folder: $folder_to_migrate - Run Command: $get_item_properties_cmd" >> "$failed_commands_file"
                    else
                        # Check the status code and process the JSON data
                        echo "In run_migrate_command - 5 - b4 calling jq"
                        http_status=$(echo "$prop_output" | jq -r '.errors[0].status')
                        echo "In run_migrate_command - 6 - after calling jq"
                        # placeholder for artifact properties
                        escaped_modified_json=""
                        if [ "$http_status" != "404" ]; then
                            echo "In run_migrate_command - 7 - b4 calling jq"
                            # The artifact has properties
                            json_data=$(echo "$prop_output" | jq -c '.properties')
                            echo "In run_migrate_command - 8 - b4 calling jq"
                            # Construct the modified JSON data dynamically
                            #  escaped_modified_json=$(echo "$modified_json" | sed 's/"/\\"/g')
                            escaped_modified_json="{\"props\": $json_data}"
                            # Run the PATCH request using the modified JSON data to set the properties for the artifact after upload
                        
                        fi
                        # Execute the migration commands for a single file in the background
                        execute_artifact_migration "$folder_position" "$source_repo" "$line" "$source_artifactory" \
                        "$target_repo" "$target_artifactory" "$escaped_modified_json" &

                        # Limit the number of concurrent background execute_artifact_migration jobs 
                        job_count=$(jobs -p | wc -l)
                        if [ "$job_count" -ge 16 ]; then
                            wait
                        fi

                    fi

                done < "$c"
            else 
                echo "Wrong 5th Parameter, 5th parameter value should be yes or no"
            fi 
        else
            echo "The file $c is either empty or doesn't exist."
        fi
        # Wait for execute_artifact_migration background jobs to complete
        wait
       rm -f "$a" "${a}.tmp" "$b" "${b}.tmp" "$c"
    fi
}


# Function to run the migration for a folder and its sub-folders
run_migration_for_folder() {
    local src_list_command="$1" 
    local target_list_command="$2"
    local folder_to_migrate="$3"
    local folder_position="$4"  # Pass the folder position as an argument
    local sibling_folder_count="$5"
    local top_or_inner="$6"

    # Create and run a background job for the folder
    (
        run_migrate_command "$src_list_command" "$target_list_command" "$folder_to_migrate" "$folder_position" "$sibling_folder_count" "$top_or_inner"
    ) &

    # Check the number of background run_migrate_command jobs and wait for them to complete if it exceeds 5
    job_count=$(jobs -p | wc -l)
    if [ $job_count -ge 5 ]; then
        wait
    fi


}

migrateFolderRecursively(){
 # Define a stack to keep track of folders to process
folder_stack=("$1")

# Iterate until the stack is empty
while [ ${#folder_stack[@]} -gt 0 ]; do
    # Pop the top folder from the stack
    l_root_folder="${folder_stack[-1]}"
    unset 'folder_stack[${#folder_stack[@]}-1]'

    echo "Processing folder: $l_root_folder"

    # Find all the sub-folders of the $l_root_folder
    if [ "$l_root_folder" != "." ]; then
        output=$(jf rt curl -s -k -XGET "/api/storage/$source_repo/$l_root_folder?list&deep=1&depth=1&listFolders=1" --server-id $source_artifactory)
    else
        output=$(jf rt curl -s -k -XGET "/api/storage/$source_repo?list&deep=1&depth=1&listFolders=1" --server-id $source_artifactory)
    fi

    echo "In migrateFolderRecursively - 1 - b4 calling jq"
    # Parse the JSON output using jq and get the "uri" values for folders
    # echo "$output"
    folders=$(echo "$output"  | jq -r '.files[] | select(has("folder") and .folder != null and .folder == true and has("uri") and .uri != null) |  .uri') 

    echo "In migrateFolderRecursively - 2 - after calling jq"

    # Split folders into an array
    IFS=$'\n' read -rd '' -a folders_array <<< "$folders"

    # Calculate the total number of sub-folders
    local total_folders=$(( ${#folders_array[@]} ))
    echo "total_folders is $total_folders . is it > 1"

    if [ "$total_folders" -gt 1 ]; then
        echo "yes it is ......"
        for folder_position in "${!folders_array[@]}"; do
            folder="${folders_array[$folder_position]}"
            #Remove the leading slash i.e if folder is "/abc" it becomes "abc"
            folder="${folder#/}"
            if [ -n "$folder" ]; then # folder is not null
                # Check if the folder name is ".conan" and skip it as it will be generated
                if [[ "$EXCLUDE_FOLDERS" == *";$folder;"* ]]; then
                    continue  # Skip this iteration of the loop
                fi

                # Push the subfolder onto the stack for processing
                if [ "$l_root_folder" = "." ]; then
                    folder_to_migrate="$folder"
                else
                    folder_to_migrate="$l_root_folder/$folder"
                fi
                # folder_to_migrate="$l_root_folder/$folder"
                folder_stack+=("$folder_to_migrate")
            fi
        done
    else 
         echo "no this is the leaf folder......"
        for folder_position in "${!folders_array[@]}"; do
            folder="${folders_array[$folder_position]}"
            #Remove the leading slash i.e if folder is "/abc" it becomes "abc"
            folder="${folder#/}"
            if [ -n "$folder" ]; then # folder is not null
                # Check if the folder name is ".conan" and skip it as it will be generated
                if [[ "$EXCLUDE_FOLDERS" == *";$folder;"* ]]; then
                    continue  # Skip this iteration of the loop
                fi

                # Process the subfolder
                if [ "$l_root_folder" = "." ]; then
                    folder_to_migrate="$folder"
                else
                    folder_to_migrate="$l_root_folder/$folder"
                fi

                # echo "Processing folder: $folder_to_migrate"
                processLeafFolderContents "$folder_to_migrate"
            fi
        done
    fi
done
}

processLeafFolderContents() {
    local folder_to_migrate="$1"  

    # echo " In processLeafFolderContents folder_to_migrate is '$folder_to_migrate'"

    # migrate files in the sub-folder
    src_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $source_artifactory --insecure \
    --data 'items.find({\"repo\":  {\"\$eq\":\"$source_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate\"},\
        \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"
    

    target_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $target_artifactory --insecure \
    --data 'items.find({\"repo\":  {\"\$eq\":\"$target_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate\"},\
        \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"


    #Call the migrate command without the trailing * to migrate files in  $folder_to_migrate  
    #folder_to_migrate="${folder_to_migrate/%\*/}"  # Remove the trailing "*"
    # run_migration_for_folder "$src_files_list_in_this_folder_command" "$target_files_list_in_this_folder_command" "$folder_to_migrate" "$((folder_position+1))" "$total_folders"
    run_migration_for_folder "$src_command1" "$target_command1" "$folder_to_migrate" "1" "1" "top"

    # Now migrate the  subfolders of $folder_to_migrate:

    src_command2="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $source_artifactory --insecure \
    --data 'items.find({\"repo\":  {\"\$eq\":\"$source_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate/*\"},\
        \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"
    

    target_command2="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $target_artifactory --insecure \
    --data 'items.find({\"repo\":  {\"\$eq\":\"$target_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate/*\"},\
        \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"



    #Call the migrate command with the trailing * to migrate folders  in $folder_to_migrate
    # run_migration_for_folder "$src_list_in_subfolders_command" "$target_list_in_subfolders_command" "$folder_to_migrate" "$((folder_position+1))" "$total_folders"
    run_migration_for_folder "$src_command2" "$target_command2" "$folder_to_migrate" "1" "1" "inner"

    # Check if the folder exists
    # echo "1st  for loop In $(pwd) - Checking Folder $((folder_position+1))/$folder_to_migrate is empty . If empty remove. ---->" >> "$failed_commands_file"
    # echo "$(du -sh $((folder_position+1))/$folder_to_migrate)" >> "$failed_commands_file"
    # echo "$(ls -al $((folder_position+1))/$folder_to_migrate)" >> "$failed_commands_file"


    # Wait for any remaining run_migration_for_folder background jobs to complete
    wait

    # Loop through the folders numbered >=1  i.e output/1 , output/2 .. and delete the folders .
    # The files in folder 0 are artifacts so are already deleted.
    # So folder 0 should already be empty.


    # Check if the folder exists        
    if [ -d "1/$folder_to_migrate" ]; then
        # Check if the folder is empty
        if [ -z "$(find 1/$folder_to_migrate -type f 2>/dev/null)" ]; then
        #if [ "$(du -s $((folder_position+1))/$folder_to_migrate | awk '{print $1}')" -eq 0 ]; then
            echo "Folder 1/$folder_to_migrate is empty, removing..." >> "$successful_commands_file"
            rm -rf "1/$folder_to_migrate"
        else
            echo "Folder '1/$folder_to_migrate' is not empty." >> "$failed_commands_file"
            echo "$(du -s 1/$folder_to_migrate | awk '{print $1}')"  >> "$failed_commands_file"
            # Add additional actions for non-empty folders here if needed
        fi
    fi

}


# processFolderContents() {
#     local l_root_folder="$1"  

#     src_list_command=""
#     target_list_command=""


#     # Find all the sub-folders of the $l_root_folder
#     if [ "$l_root_folder" = "." ]; then
#         output=$(jf rt curl -s -k -XGET "/api/storage/$source_repo?list&deep=1&depth=1&listFolders=1" --server-id $source_artifactory)
#     else
#         output=$(jf rt curl -s -k -XGET "/api/storage/$source_repo/$l_root_folder?list&deep=1&depth=1&listFolders=1" --server-id $source_artifactory)
#     fi

#     echo "In processFolderContents - 1 - b4 calling jq"
#     # Parse the JSON output using jq and get the "uri" values for folders
#     echo "$output"
#     folders=$(echo "$output" | jq -r '.files[] | select(has("folder") and .folder != null) |  .uri')
#     echo "In processFolderContents - 2 - after calling jq"

#     # Split folders into an array
#     IFS=$'\n' read -rd '' -a folders_array <<< "$folders"
   
#     echo "In processFolderContents - 3 - b4  calculating total_folders"
#     # Calculate the total number of sub-folders
#     total_folders="$(expr "${#folders_array[@]}" + 1)"
#     echo "In processFolderContents - 4 - after  calculating total_folders"

#     # Loop through the sub-folders and generate the jf rt  commands
#     for folder_position in "${!folders_array[@]}"; do
#         folder="${folders_array[$folder_position]}"
#         #Remove the leading slash i.e if folder is "/abc" it becomes "abc"
#         folder="${folder#/}"



#         src_list_command=""
#         target_list_command=""


#         if [ "$l_root_folder" = "." ]; then
#             folder_to_migrate="$folder"
#         else
#             folder_to_migrate="$l_root_folder/$folder"
#         fi
#         echo " In processFolderContents folder_to_migrate is '$folder_to_migrate'"

#         # migrate files in the sub-folder
#         src_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $source_artifactory --insecure \
#         --data 'items.find({\"repo\":  {\"\$eq\":\"$source_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate\"},\
#             \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"
        

#         target_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $target_artifactory --insecure \
#         --data 'items.find({\"repo\":  {\"\$eq\":\"$target_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate\"},\
#             \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"

#         # Concatenate the two commands 
#         # src_files_list_in_this_folder_command="$src_command1 $jq_sed_command"
#         # target_files_list_in_this_folder_command="$target_command1 $jq_sed_command"
        
#         #    echo $src_list_command
#         #    echo $target_list_command

#         #Call the migrate command without the trailing * to migrate files in  $folder_to_migrate  
#         #folder_to_migrate="${folder_to_migrate/%\*/}"  # Remove the trailing "*"
#         # run_migration_for_folder "$src_files_list_in_this_folder_command" "$target_files_list_in_this_folder_command" "$folder_to_migrate" "$((folder_position+1))" "$total_folders"
#         run_migration_for_folder "$src_command1" "$target_command1" "$folder_to_migrate" "$((folder_position+1))" "$total_folders" "top"

#         # Now migrate the  subfolders of $folder_to_migrate:

#         src_command2="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $source_artifactory --insecure \
#         --data 'items.find({\"repo\":  {\"\$eq\":\"$source_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate/*\"},\
#             \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"
        

#         target_command2="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $target_artifactory --insecure \
#         --data 'items.find({\"repo\":  {\"\$eq\":\"$target_repo\"}, \"path\": {\"\$match\": \"$folder_to_migrate/*\"},\
#             \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"

#         # Concatenate the two commands 
#         # src_list_in_subfolders_command="$src_command2 $jq_sed_command"
#         # target_list_in_subfolders_command="$target_command2 $jq_sed_command"

#         #Call the migrate command with the trailing * to migrate folders  in $folder_to_migrate
#         # run_migration_for_folder "$src_list_in_subfolders_command" "$target_list_in_subfolders_command" "$folder_to_migrate" "$((folder_position+1))" "$total_folders"
#         run_migration_for_folder "$src_command2" "$target_command2" "$folder_to_migrate" "$((folder_position+1))" "$total_folders" "inner"

#         # Check if the folder exists
#         # echo "1st  for loop In $(pwd) - Checking Folder $((folder_position+1))/$folder_to_migrate is empty . If empty remove. ---->" >> "$failed_commands_file"
#         # echo "$(du -sh $((folder_position+1))/$folder_to_migrate)" >> "$failed_commands_file"
#         # echo "$(ls -al $((folder_position+1))/$folder_to_migrate)" >> "$failed_commands_file"
#     done 

#     # Wait for any remaining run_migration_for_folder background jobs to complete
#     wait

#     # Loop through the folders numbered >=1  i.e output/1 , output/2 .. and delete the folders .
#     # The files in folder 0 are artifacts so are already deleted.
#     # So folder 0 should already be empty.
#     for folder_position in "${!folders_array[@]}"; do
#         folder="${folders_array[$folder_position]}"
#         #Remove the leading slash i.e if folder is "/abc" it becomes "abc"
#         folder="${folder#/}"
#         # $EXCLUDE_FOLDERS like ".conan" are not there , so skip
#         if [[ "$EXCLUDE_FOLDERS" == *";$folder;"* ]]; then
#             continue  # Skip this iteration of the loop
#         fi

#         if [ -z "$l_root_folder" ]; then
#             folder_to_migrate="$folder"
#         else
#             folder_to_migrate="$l_root_folder/$folder"
#         fi

#         # Check if the folder exists        
#         if [ -d "$((folder_position+1))/$folder_to_migrate" ]; then
#             # Check if the folder is empty
#             if [ -z "$(find $((folder_position+1))/$folder_to_migrate -type f 2>/dev/null)" ]; then
#             #if [ "$(du -s $((folder_position+1))/$folder_to_migrate | awk '{print $1}')" -eq 0 ]; then
#                 echo "Folder $((folder_position+1))/$folder_to_migrate is empty, removing..." >> "$successful_commands_file"
#                 rm -rf "$((folder_position+1))/$folder_to_migrate"
#             else
#                 echo "Folder '$((folder_position+1))/$folder_to_migrate' is not empty." >> "$failed_commands_file"
#                 echo "$(du -s $((folder_position+1))/$folder_to_migrate | awk '{print $1}')"  >> "$failed_commands_file"
#                 # Add additional actions for non-empty folders here if needed
#             fi
#         fi
#     done
# }


# Check if the fifth parameter (root-folder) is provided
if [ $# -ge 7 ]; then
    root_folder="$7"
else 
    root_folder="."
fi
# check for files in the root folder:
src_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $source_artifactory --insecure \
--data 'items.find({\"repo\":  {\"\$eq\":\"$source_repo\"}, \"path\": {\"\$match\": \"$root_folder\"},\
    \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"


target_command1="jf rt curl -s -XPOST -H 'Content-Type: text/plain' api/search/aql --server-id $target_artifactory --insecure \
--data 'items.find({\"repo\":  {\"\$eq\":\"$target_repo\"}, \"path\": {\"\$match\": \"$root_folder\"},\
    \"type\": \"file\"}).include(\"repo\",\"path\",\"name\",\"sha256\")'"



#Call the migrate command without the trailing * to migrate files in the $root_folder 
run_migrate_command "$src_command1" "$target_command1" "$root_folder" "0" "0" "top"

# Process sub-folders
migrateFolderRecursively "$root_folder"


echo "All transfers for $source_repo completed" >> "$successful_commands_file"


