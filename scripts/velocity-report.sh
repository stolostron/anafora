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

# Set pipeline names.
PLAYBACK="Ready For Playback"
PRODUCT="Product Backlog"
RELEASE="Release Backlog"
SPRINT="Sprint Backlog"
UNTRIAGED="Untriaged"
INPROGRESS="In Progress"

# Base repository.
BASE_REPO="https://github.com/${ORG}/anafora"

# Squad label that is used in Github.
SQUAD=$SQUAD

## GitHub env variables.
GITHUB_TOKEN=$GITHUB_TOKEN

## Zenhub env variables.
ZENHUB_TOKEN=$ZENHUB_TOKEN

## Slack env variables.
SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL

# Create the directory that will contain the reports.
REPORT_DIR=${REPORT_DIR:-"report/$(date +%m-%d-%y)"}
mkdir -p $REPORT_DIR

# Set the filepath for the report file.
REPORT_FILE_NAME=velocity-report-$(date +%s)

if [[ -z $GITHUB_TOKEN || -z $SLACK_WEBHOOK_URL || -z $ZENHUB_TOKEN ]]; then
    ERROR="Error: One or more of the following environment variables: (GITHUB_TOKEN, SLACK_WEBHOOK_URL, ZENHUB_TOKEN) was not exported. Export the variables to run the script."
    printf "$ERROR" > $REPORT_DIR/$REPORT_FILE_NAME.log
    echo $ERROR && exit 1
fi

# Clean up resources/files that doesn't need be kept around after execution.
cleanup () {
    rm ISSUES_LIST ISSUE_ESTIMATE
}

push_report_to_slack () {
    STATUS=warning
    SUBTEXT=":$STATUS: There are $TOTAL_PR_COUNT active pull requests opened! Please remember to review or close any inactive pull request."

    curl -X POST -H 'Content-type: application/json' --data \
    '{
        "attachments": [
            {
                "title": "View Pull Request Report in Github -> Anafora",
                "title_link": "https://github.com/stolostron/anafora/blob/main/README.md",
                "text": "'"$(cat $TXT_REPORT_FILE)"'",
                "color": "'"${STATUS}"'"
            }
        ],
        "text": ":announcement: Hello team! Here is your weekly `GitHub Pull Requests Report`!\n\n'"${SUBTEXT}"'"
    }' $SLACK_WEBHOOK_URL
}

# File that will be used for the slack bot message. (.md reports will be generated within the future)
TXT_REPORT_FILE="$REPORT_DIR/${REPORT_FILE_NAME}.txt"

gh issue list -R $ORG/$BACKLOG --label=$SQUAD,user_story --limit=100 --json=title,number | jq -r '.[] | (.number|tostring) + "|" +.title' > ISSUES_LIST

# Retrieve issue estimate and pipeline data.
while IFS='|' read -ra ISSUE; do
    ESTIMATE=$(curl -s -H "X-Authentication-Token: $ZENHUB_TOKEN" "https://api.zenhub.io/p1/repositories/239633281/issues/$ISSUE" | jq -r '. | (.estimate.value|tostring) + "|" + .pipelines[0].name')
    echo "${ISSUE[0]}|${ISSUE[1]}|$ESTIMATE" >> ISSUE_ESTIMATE
done < ISSUES_LIST

if [[ ! -s ISSUES_LIST ]]; then
    echo -e "There are currently no user stories assigned to ${PURPLE}$SQUAD${NC}\n"
else
    echo -e "Found the following user stories within the $ORG/$BACKLOG repo that are assigned to ${PURPLE}$SQUAD${NC}\n"
    while IFS='|' read -ra ISSUE; do
        NUMBER=${ISSUE[0]}
        TITLE=${ISSUE[1]}
        ESTIMATE=${ISSUE[2]}
        PIPELINE=${ISSUE[3]}

        # Display issue number and title.
        echo -e "• $NUMBER - $TITLE"

        MESSAGE='\t• <https://github.com/'$ORG/$BACKLOG'/issues/'$NUMBER'|'$NUMBER'> - '$TITLE'. (Estimated:`'$ESTIMATE'` points)\n'
        WARNING="Warning: ($PIPELINE) https://github.com/$ORG/$BACKLOG/issues/$NUMBER is not story pointed. Please review the user story and add an estimation."

        if [[ "$PIPELINE" == "$SPRINT" || "$PIPELINE" == "$INPROGRESS" || "$PIPELINE" == "$PLAYBACK" ]]; then
            if [[ $ESTIMATE == "null" ]]; then
                echo -e "${YELLOW}$WARNING${NC}"

                MESSAGE='\t• <https://github.com/'$ORG'/'$BACKLOG'/issues/'$NUMBER'|'$NUMBER'> - '$TITLE' is not pointed; however it is currently in the `'${PIPELINE}' pipeline`. Please review the user story and add an estimation.\n'
                echo -e $MESSAGE >> $TXT_REPORT_FILE
            else
                MESSAGE='\t• <https://github.com/'$ORG/$BACKLOG'/issues/'$NUMBER'|'$NUMBER'> - '$TITLE'. (Estimated:`'$ESTIMATE'` points - `'$PIPELINE'`)\n'
                echo -e $MESSAGE >> $TXT_REPORT_FILE
            fi
        else
            if [[ $ESTIMATE == "null" ]]; then
                echo -e "${YELLOW}$WARNING${NC}"
                printf "$WARNING\n" >> $REPORT_DIR/$REPORT_FILE_NAME.log
            fi
        fi

        echo -e ""
    done < ISSUE_ESTIMATE
fi

push_report_to_slack
cleanup

exit 0
