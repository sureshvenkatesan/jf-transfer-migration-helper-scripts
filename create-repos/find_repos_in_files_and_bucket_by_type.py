"""
Read each repo name from a input file  and if the repo is in any of the  3 repo types ["all_local_repos_in_ncr.txt", "all_remote_repos_in_ncr.txt", "all_virtual_repos_in_ncr.txt"]
 I want to put it  in a found_in_<filename>.txt where the <filename> is the name of the 3 files:
 Usage: python find_repos_in_files_and_bucket_by_type.py
"""
def find_lines_in_files(input_filename, file_list):
    found_lines = {filename: [] for filename in file_list}

    with open(input_filename, 'r') as input_file:
        for line in input_file:
            line = line.strip()
            for filename in file_list:
                with open(filename, 'r') as target_file:
                    if line in target_file.read():
                        found_lines[filename].append(line)

    for filename, lines in found_lines.items():
        if lines:
            with open(f'found_in_{filename}', 'w') as output_file:
                output_file.write('\n'.join(lines))

if __name__ == "__main__":
    input_filename = "2_high_priority_not_in_ncratleos.08222023"
    file_list = ["all_local_repos_in_ncr.txt", "all_remote_repos_in_ncr.txt", "all_virtual_repos_in_ncr.txt"]
    find_lines_in_files(input_filename, file_list)
