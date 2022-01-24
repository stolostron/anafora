#!/bin/bash

####################
## COLORS
####################
PURPLE="\033[0;35m"
YELLOW="\033[0;33m"
NC="\033[0m"

# Set org name.
ORG=stolostron

# Base repository.
BASE_REPO="https://github.com/${ORG}/anafora"

## GitHub env variables.
GITHUB_TOKEN=$GITHUB_TOKEN

## Slack env variables.
SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL

# Create the directory that will contain the reports.
REPORT_DIR=${REPORT_DIR:-"report/$(date +%m-%d-%y)"}
mkdir -p $REPORT_DIR

# Set the filepath for the report file.
REPORT_FILE_NAME=pr-report-$(date +%s)

if [[ -z $GITHUB_TOKEN || -z $SLACK_WEBHOOK_URL ]]; then
    ERROR="Error: One or more of the following environment variables: (GITHUB_TOKEN, SLACK_WEBHOOK_URL) was not exported. Export the variables to run the script."
    printf "$ERROR" > $REPORT_DIR/$REPORT_FILE_NAME.log
    echo $ERROR && exit 1
fi

# Set the path for the file that will contain the repository list.
REPOSITORIES_FILE_PATH=${REPOSITORIES_FILE_PATH:-"$(pwd)/REPOSITORIES"}

# Repositories that will be scanned and mentioned within the pull request report.
if [[ ! -f $REPOSITORIES_FILE_PATH ]]; then
    ERROR="Error: Failed to find repository file located at: $REPOSITORIES_FILE_PATH. Check the file path and ensure the path is correct."
    printf "$ERROR" > $REPORT_DIR/$REPORT_FILE_NAME.log
    echo $ERROR && exit 1
else
    echo -e "Found repository file located at: $REPOSITORIES_FILE_PATH"
    REPOSITORIES=$(cat ${REPOSITORIES_FILE_PATH})
fi

# Clean up resources/files that doesn't need be kept around after execution.
cleanup () {
    rm PULL_REQUEST
}

# Convert Github username to Slack username.
convert_author_gh_slack () {
    while IFS=':' read -ra USERNAME
    do
        if [[ $1 == ${USERNAME[0]} ]]; then
            AUTHOR=${USERNAME[1]}
            FOUND_MATCH=true
            break
        else
            FOUND_MATCH=false
        fi
    done < SQUAD_USERNAMES

    if [[ $FOUND_MATCH == "false" ]]; then
        ERROR="Warning: In $REPO repo, @$1 is the author of pr: $PR_NUMBER; however, the username is not mapped to any id within the SQUAD_USERNAME list."
        printf "$ERROR\n" >> $REPORT_DIR/$REPORT_FILE_NAME.log
        echo -e "$ERROR"
    fi
}

push_report_to_slack () {
    if [ $TOTAL_PR_COUNT -le 10 ]; then
        STATUS=good
    else
        STATUS=warning
    fi

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

TOTAL_PR_COUNT=0

for REPO in $REPOSITORIES; do
    echo -e "\n${YELLOW}Checking $REPO for open pull request${NC}"
    MESSAGE="\nCurrent active <https://www.github.com/$REPO/pulls|PRs> in $REPO"

    # Capture the available PR data from the targeted repository.
    gh pr list -R $REPO > PULL_REQUEST

    if [[ ! -s PULL_REQUEST ]]; then
        echo -e "\t• There are no open pull requests in ${PURPLE}$REPO${NC}\n"
    else
        echo -e "\t• Found open pull requests in ${PURPLE}$REPO${NC}\n"
        echo -e $MESSAGE >> $TXT_REPORT_FILE

        while IFS= read -r PR
        do
            PR_NUMBER=$(echo $PR | head -n1 | awk '{print $1;}')
            AUTHOR=$(gh pr list -R $REPO --search=${PR_NUMBER} --json=author | jq -r .[].author.login)

            convert_author_gh_slack $AUTHOR
            echo -e "\t• <https://www.github.com/$REPO/pull/$PR_NUMBER|$PR> <@$AUTHOR>" >> $TXT_REPORT_FILE

            TOTAL_PR_COUNT=$(($TOTAL_PR_COUNT + 1))
        done < PULL_REQUEST
    fi
done

echo -e "Total # of prs opened: $TOTAL_PR_COUNT\n"

push_report_to_slack
cleanup

exit 0
