BEGIN {
    require 'octokit'
    require_relative '../../config/index'

    Octokit.configure do |c|
        c.auto_paginate = true
    end

    Config.initialize

    client = Octokit::Client.new(:access_token => $GITHUB_TOKEN)
}

END {
    puts "Exiting Jira issue importer...\n"
}

# Create a csv file to be imported into Jira.
# @param filename - The name of the csv file.
# @return file - The csv file that was created.
def create_csv_file_for_jira_import(filename)
    file = File.new(filename, "w")
    file.puts("Component/s,Issue Type,Summary,Description,Labels,Assignee,Priority,Severity,Blocked,Epic Name")

    return file
end

# Map blocked status to the Jira fields.
# @param issue - The GitHub issue.
# @return blocked - The blocked status assigned to the issue.
def map_blocked_status_to_jira(issue)
    return issue.labels.any? {|label| label.name == "blocked"}
end

# Map blocked status to the Jira fields.
# @param issue - The GitHub issue.
# @return blocked - The blocked status assigned to the issue.
def map_epic_name_to_jira(issue)
    if issue.labels.any? {|label| label.name == "blog" || label.name == "bug" || label.name == "enhancement" || label.name == "task" || label.name == "user_story" }
        return ""
    end

    return issue.title
end

# Map issue severity and priority to the Jira fields.
# @param issue - The GitHub issue.
# @param type - The GitHub issue type.
# @return severity - The severity assigned to the GitHub issue.
# @return priority - The priority assigned to the GitHub issue.
def map_severity_priority_to_jira(issue, type)
    severity, priority = "", "Normal"

    # Jira bugs are the only issue type that requires severity
    if type == "bug"
        severity = "None"

        if issue.labels.any? {|label| label.name == "Severity 1 - Urgent" || label.name == "Priority/P1" }
            severity, priority = "Critical", "Critical"
        elsif issue.labels.any? {|label| label.name == "Severity 2 - Major" || label.name == "Priority/P2" }
            severity, priority = "Important", "Major"
        elsif issue.labels.any? {|label| label.name == "Severity 3 - Minor" || label.name == "Priority/P3" }
            severity, priority = "Low", "Minor"
        end
    end

    return severity, priority
end

# Map the GitHub user to their Red Hat email (required when mapping assignees to issues within Jira).
# @param filename - The name of the csv file.
# @param user - The GitHub user.
# @return email - The Red Hat email of the GitHub user.
def map_user_to_id(filename, user)
    File.open(filename) do |file|
        data = file.find {|line| line =~ /#{user}/}

        if !data.nil?
            puts "\t[√]: User #{user} detected.".green
            return "#{data.split(',')[1].strip}"
        end
    end

    puts "\t[X]: User #{user} not detected.".red
    return ""
end

# Write data to the csv file.
# @param file - The file to write the data into.
# @param issues - The GitHub issue.
# @param component - The ACM component to assign the issues to within Jira.
def write_issues_to_csv(file, issues, component, labels)
    types = ['blog', 'bug', 'enhancement', 'task', 'user_story', 'Epic']
    formatted_issues = []

    types.each do |type|
        puts "Preparing to write issue type: (#{type}) to CSV file.".yellow

        items = issues.select {|issue| issue.labels.any? {|label| label.name == type }}
        puts "(#{items.length}) #{type} detected:\n".magenta

        # Jira defines their user stories as story.
        if type == 'user_story'
            type = 'story'

        elsif type == 'enhancement'
            type = "feature"

        elsif type == 'blog'
            type = 'task'
        end

        items.each do |issue|
            if !formatted_issues.include?(issue.number)
                puts "\t• #{issue.number} - #{issue.title}".cyan

                # Map the assignees to the Jira field.
                assignee = ""
                if issue.assignees.none?
                    puts "\tNo assignee detected.".yellow
                else
                    issue.assignees.each do |user|
                        assignee = map_user_to_id("users.txt", user.login)
                        break
                    end
                    puts "\tAssignee: #{assignee}"
                end

                # Map the blocked status to the Jira field.
                blocked = map_blocked_status_to_jira(issue)
                puts "\tBlocked: #{blocked}"

                # Map the labels to the Jira field.
                puts "\tLabel(s): #{labels}"

                # Map the severity and priority to the Jira fields.
                severity, priority = map_severity_priority_to_jira(issue, type)
                puts "\tSeverity: #{severity}\n\tPriority: #{priority}"

                # Map the epic name to the Jira field.
                epic_name = map_epic_name_to_jira(issue)
                puts "\tEpic Name: #{epic_name}\n\n"

                formatted_issues.push(issue.number)
                file.puts("#{component},#{type},\"#{issue.title}\",\"Migrated issue from: #{issue.html_url}\",\"#{labels}\",\"#{assignee}\",\"#{priority}\",\"#{severity}\",#{blocked},\"#{epic_name}\"")
            else
                puts "\t• #{issue.number} - #{issue.title}".cyan
                puts "\tIssue: #{issue.number} has already been formatted within the CSV file\n".yellow
            end
        end
    end
end

def main (client)
    issues = client.list_issues($BACKLOG, :labels =>"#{$SQUAD_LABEL},Move to Jira - Required", :direction => 'asc')

    if issues.length == 0
        puts "No issues detected for #$SQUAD_LABEL with the \"Move to Jira - Required\" label"
        exit 0
    end

    puts "Enter the CSV filename to be created:"
    filename = gets.chomp

    puts "\nEnter the Jira labels that will be assigned to the issue:"
    label = gets.chomp

    puts "\nEnter the name of the Jira component for the issue to be assigned to:"
    component = gets.chomp

    file = create_csv_file_for_jira_import(filename)
    write_issues_to_csv(file, issues, component, label)
    file.close

    if File.exists?(filename)
        puts "CSV file created: #{filename}".cyan
    else
        abort "CSV file creation failed... Aborting script run.".red
    end

    puts "Would you like to open Jira to import the issues: (Press ENTER for default: y)"
    input = gets.chomp

    if input.empty? || input == "Y" || input == "y"
        puts "Opening Jira (the user maybe required to log into Jira).\n".cyan
        system("open", "https://issues.redhat.com/secure/BulkCreateSetupPage!default.jspa?externalSystem=com.atlassian.jira.plugins.jira-importers-plugin:bulkCreateCsv")

        puts "Have the issues been migrated over to Jira: (Press ENTER for default: y)"
        input = gets.chomp

        if input.empty? || input == "Y" || input == "y"
            puts "\nUpdating the imported issues labels within the #{$BACKLOG} repo with \"Move to Jira - Done\".".cyan

            comment = "This issue has been migrated to Jira. Link: TBD"
            issues.each do |issue|
                client.remove_label($BACKLOG, issue.number, "Move to Jira - Required")
                client.add_labels_to_an_issue($BACKLOG, issue.number, ['Move to Jira - Done'])
                client.add_comment($BACKLOG, issue.number, comment)
                puts "[UPDATED] #{issue.number} - #{issue.title}"
            end
        end
    end
end

main(client)
