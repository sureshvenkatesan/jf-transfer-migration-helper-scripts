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

### Exit the script on any failures
## define variable
cd maven-repos
jf c use ncratleos


cat non-unique-maven-snapshotVersionBehavior.list |  while read line
do
    REPO=$(echo $line | cut -d ':' -f 2)
    echo "Getting configuration for "$REPO
    jf rt curl api/repositories/$REPO >> $REPO-config.json

    cp $REPO-config.json $REPO-config-before-change.json

    tempfile=$(mktemp -u)
    jq --arg sub "unique" '.snapshotVersionBehavior|= $sub' "$REPO-config.json" > "$tempfile"
    mv "$tempfile" "$REPO-config.json"
    mv $REPO-config-before-change.json backup-ncratleos

    data=$( jf rt curl  -X POST api/repositories/$REPO -H "Content-Type: application/json" -T $REPO-config.json --server-id=ncratleos -s | grep message | xargs)
    echo $data
    if [[ $data == *"message"*  ]];then
        echo "$REPO" >> conflicting-repos.txt
    fi
done