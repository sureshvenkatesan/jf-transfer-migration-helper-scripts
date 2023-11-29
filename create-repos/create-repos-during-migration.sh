#! /bin/bash
# JFrog hereby grants you a non-exclusive, non-transferable, non-distributable right
# to use this  code   solely in connection with your use of a JFrog product or service.
# This  code is provided 'as-is' and without any warranties or conditions, either
# express or implied including, without limitation, any warranties or conditions of
# title, non-infringement, merchantability or fitness for a particular cause.
# Nothing herein shall convey to you any right or title in the code, other than
# for the limited use right set forth herein. For the purposes hereof "you" shall
# mean you as an individual as well as the organization on behalf of which you
# are using the software and the JFrog product or service.

### sample cmd to run - ./create-repos-during-migration.sh source-server target-server remote "air-gapped-npm-remote;sv-docker-remote"

### Exit the script on any failures
## define variables
source="${1:?source-serverId ex - source-server}"
target="${2:?target-serverId . ex - target-server}"
TYPE="${3:?please enter type of repo. ex - local, remote, virtual, federated, all}"
includerepos="${4:-}" # Optional semicolon-separated list of repos to include
excluderepos="${5:-artifactory-build-info;_intransit}" # Optional semicolon-separated list of repos to exclude with default value


mkdir -p repository
cd repository

reposfile="repositories.list"
rm -rf repositories.list
rm -rf *config.json

jf config use ${source}

### Run the curl API
jf rt curl api/repositories?type=${TYPE} -s | jq -rc '.[] | .key' > $reposfile

cat $reposfile |  while read line
do
    REPO=$(echo $line | cut -d ':' -f 2)
    echo "Getting configuration for "$REPO

    if [[ -n "$excluderepos" ]] && [[ "$excluderepos" == *$REPO* ]]; then
        echo "Skipping excluded Repo" $REPO
    # elif [[ -n "$includerepos" ]] && [[ "$includerepos" != *$REPO* ]]; then
    elif [[ -n "$includerepos" ]] && [[ ! "$includerepos" =~ (^|;)${REPO}(;|$) ]]; then
        echo "Skipping Repo not in includerepos" $REPO
    else
        jf rt curl api/repositories/$REPO >> $REPO-config.json
        echo creating repo -- $REPO on $target

        # Check if "rclass" is "remote" and "password" is not empty, replace "password" with ""
        jq '. |= if .rclass == "remote" and .password != "" then .password = "" else . end' $REPO-config.json > temp.json
        mv temp.json $REPO-config.json

        data=$( jf rt curl  -X PUT api/repositories/$REPO -H "Content-Type: application/json" -T $REPO-config.json --server-id=$target -s | grep message | xargs)
        echo $data
        if [[ $data == *"message"*  ]];then
            echo "$REPO" >> conflicting-repos.txt
        fi
    fi

done
