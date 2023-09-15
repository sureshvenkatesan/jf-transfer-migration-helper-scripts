## Readme for [sv_test_migrate_folder.sh](sv_test_migrate_folder.sh)

Script for migrating folders directly from usvartifactory5 liquid  to jfrogio liquid ( conan) repo . It has a dependency on the "jq" utility .
Please install jq on usvartifactory5 as mentioned in https://www.cyberithub.com/how-to-install-jq-json-processor-on-rhel-centos-7-8/ :
```
yum install jq -y
rpm -qa | grep -i jq
jq -Version
```

I am planning to run it as the following to first copy the liquid/test folder :
```
screen -dmS myjfsession bash -c './sv_test_migrate_folder.sh usvartifactory5 liquid jfrogio liquid  yes  test | xargs -P 8 -I {} sh -c '{}' 2>&1 | tee jf_output.log; exec bash'
```

Every time you  run the script by specifying a folder it will first do a diff between that folder and its subfolders ( between usvartifactory5 and  jfrogio  ) ,
 then  download the folders in batches and upload to jfrogio using the jfrog cli. That way we can sync the deltas as well.

 ---
 ## Readme for [sv_test_migrate_folder_modular.sh](sv_test_migrate_folder_modular.sh)

```
 bash /Users/sureshv/myCode/github-sv/jf-transfer-migration-helper-scripts/transfer-artifacts-in-sub_folders_in_parallel/1.sh bosesh sureshv-liquid-generic bosesaas sureshv-liquid-test no  test

  bash /Users/sureshv/myCode/github-sv/jf-transfer-migration-helper-scripts/transfer-artifacts-in-sub_folders_in_parallel/1.sh bosesh sureshv-liquid-generic bosesaas sureshv-liquid-test yes  test
```

