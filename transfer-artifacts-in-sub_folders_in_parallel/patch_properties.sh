#!/bin/bash
# usage: cat properties_patch.txt | xargs -P 8 -I {} ./patch_properties.sh '{}'
#  cat properties_patch.txt | sed "s/'/\\\'/g" |  xargs   -P 8 -I {} ./patch_properties.sh '{}' properties_patch_failed.txt

command=$1
log_file=$2

# Run the command within a new shell and capture both stdout and stderr
output="$($command 2>&1)"
# output="$($SHELL -c "$command" 2>&1)"

# Check if the command was successful
if [ $? -eq 0 ]; then
    # Command was successful, log it to stdout
    echo "Command successful: $command"
else
    # Command failed, log it to stderr and the log file
    echo "Command failed: $command"
    echo "$command" >> "$log_file"
fi

# Log the output to the log file
echo "$output" >> "$log_file"