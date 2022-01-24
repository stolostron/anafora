# Anafora

## Scripts

Scripts for interacting with the Anafora report slack bot (anafora = report). This repo is a WIP; however, if you would like to add scripts to this repo, you will need to reach out to @dislbenn to receive the webhook url for the slack bot.

### Pull Request Report

Prerequisites:

- Export the following variables:
  - GITHUB_TOKEN
  - SLACK_WEBHOOK_URL

- Copy `REPREPOSITORIES.template` => `REPREPOSITORIES` (Required to extract pull request data from targeted repositories)

Example: `REPREPOSITORIES`

```bash
stolostron/insights-chart
stolostron/insights-client
stolostron/insights-ingestor
stolostron/insights-metrics
stolostron/redisgraph-tls
stolostron/search
...

Note: The repository should be entered within the following format: `stolostron/repo_name`
```

- Copy `SQUAD_USERNAMES.template` => `SQUAD_USERNAMES` (Required to map squad's member GitHub username to Slack username)

Example: `SQUAD_USERNAMES`

```bash
dislbenn:dbennett
...
```

- Note: The username should be entered within the following format: `gh_username:slack_username`

To generate a slack report for the pull request listed within the , the user will need to run the following script:

```bash
. ./scripts/pull_request_report.sh

or

bash ./scripts/pull_request_report.sh
```

#### Environment Variables

| Name                     | Description                                                | Required |
|--------------------------|------------------------------------------------------------|----------|
| REPORT_DIR               | The directory path to where the reports will be located    | No       |
| REPOSITORIES_FILE_PATH   | The file path containing the list of repositories to check | No       |

##### Github Variables

| Name         | Description                                                | Required |
|--------------|------------------------------------------------------------|----------|
| GITHUB_TOKEN | The github token is needed to interact with the GitHub API | Yes      |

##### Slack Variables

| Name               | Description                                                      | Required |
|--------------------|------------------------------------------------------------------|----------|
| SLACK_WEBHOOK_URL  | The webhook url is needed to make a request to the slack channel | Yes      |
