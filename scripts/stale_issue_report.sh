#!/bin/bash

####################
## COLORS
####################
PURPLE="\033[0;35m"
YELLOW="\033[0;33m"
NC="\033[0m"

# Set org name.
ORG=stolostron

# Set backlog repo name.
BACKLOG=backlog

# Base repository.
BASE_REPO="https://github.com/${ORG}/anafora"

# Squad label that is used in Github.
SQUAD=$SQUAD

## GitHub env variables.
GITHUB_TOKEN=$GITHUB_TOKEN

## Slack env variables.
SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL

# Create the directory that will contain the reports.
REPORT_DIR=${REPORT_DIR:-"report/$(date +%m-%d-%y)"}
mkdir -p $REPORT_DIR

# Set the filepath for the report file.
REPORT_FILE_NAME=stale-issue-report-$(date +%s)

if [[ -z $GITHUB_TOKEN || -z $SLACK_WEBHOOK_URL ]]; then
    ERROR="Error: One or more of the following environment variables: (GITHUB_TOKEN, SLACK_WEBHOOK_URL) was not exported. Export the variables to run the script."
    printf "$ERROR" > $REPORT_DIR/$REPORT_FILE_NAME.log
    echo $ERROR && exit 1
fi

# Clean up resources/files that doesn't need be kept around after execution.
cleanup () {
    rm ISSUES_LIST
}

push_report_to_slack () {
    if [ $TOTAL_STALE_COUNT -le 5 ]; then
        STATUS=good
    else
        STATUS=warning
    fi

    SUBTEXT=':'$STATUS': There are '$TOTAL_STALE_COUNT' `stale` issues opened and assigned to the squad label: `'$SQUAD'`! Please remember to review or close any `stale` issues that are no longer needed.'

    curl -X POST -H 'Content-type: application/json' --data \
    '{
        "attachments": [
            {
                "title": "View Stale Issue Report in Github -> Anafora",
                "title_link": "https://github.com/stolostron/anafora/blob/main/README.md",
                "text": "'"$(cat $TXT_REPORT_FILE)"'",
                "color": "'"${STATUS}"'"
            }
        ],
        "text": ":announcement: Hello team! Here is your weekly `GitHub Stale Issues Report`!\n\n'"${SUBTEXT}"'"
    }' $SLACK_WEBHOOK_URL
}

# File that will be used for the slack bot message. (.md reports will be generated within the future)
TXT_REPORT_FILE="$REPORT_DIR/${REPORT_FILE_NAME}.txt"
TOTAL_STALE_COUNT=0

gh issue list -R $ORG/$BACKLOG --label=squad:observability-usa,stale --json=title,number | jq -r ' .[] | (.number|tostring) + "~" + .title' > ISSUES_LIST

echo -e "\n${YELLOW}Checking $ORG/$BACKLOG for stale issues assigned to $SQUAD${NC}\n"

if [[ ! -s ISSUES_LIST ]]; then
    echo -e "• There are currently no stale issues assigned to ${PURPLE}$SQUAD${NC}\n"
else
    echo -e "• Found the following stale issues within the $ORG/$BACKLOG repo that are assigned to $SQUAD\n"
    while IFS='~' read -ra ISSUE
    do
        echo -e "\t• ${ISSUE[0]} - ${ISSUE[1]}"
        echo -e "• <https://github.com/$ORG/$BACKLOG/issues/${ISSUE[0]}|${ISSUE[0]}> - ${ISSUE[1]}" >> $TXT_REPORT_FILE
        TOTAL_STALE_COUNT=$(($TOTAL_STALE_COUNT + 1))
    done < ISSUES_LIST
fi

echo -e "\nTotal # of stale issues opened: $TOTAL_STALE_COUNT"

push_report_to_slack
cleanup

exit 0
