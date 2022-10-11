BEGIN {
    require 'colorize'
    require 'octokit'
    require_relative '../../config/index'

    puts "Initializing Anafora Github issues labels replacer.\n".yellow

    Octokit.configure do |c|
        c.auto_paginate = true
    end

    Config.initialize

    $TARGET_LABELS=ENV['TARGET_LABELS']
    unless $TARGET_LABELS
        abort "TARGET_LABELS is required to be exported to filter for the Github issues. Aborting now.".red
    else
        puts "TARGET_LABELS: #{$TARGET_LABELS.split(',')}"
    end

    $REPLACEMENT_LABELS=ENV['REPLACEMENT_LABELS']
    unless $REPLACEMENT_LABELS
        abort "REPLACEMENT_LABELS is required to be exported to filter for the Github issues. Aborting now.".red
    else
        puts "REPLACEMENT_LABELS: #{$REPLACEMENT_LABELS.split(',')}\n\n"
    end

    client = Octokit::Client.new(:access_token => $GITHUB_TOKEN)
}

END {
    puts "\nExiting Anafora Github issues labels replacer.".yellow
}

# Add a list of labels to the targeted github issue
def add_labels_to_github_issue(client, issue, labels)
    puts "\n\t• Adding the following labels to the github issue: #{labels}"
    client.add_labels_to_an_issue("stolostron/backlog", issue.number, labels)
end

# Returns an array of labels that are missing from the targeted
# github issue.
def check_github_issue_for_missing_labels(issue, labels)
    puts "\nChecking current label(s) attached to the github issue:"
    puts "\t• #{issue.html_url} - #{issue.title}".blue

    issue.labels.each do |l|
        if labels.find { |label| label === l.name }
            puts "\t\t• #{l.name} (target found)".cyan
            
            index = labels.find_index { |label| label == l.name }
            labels.delete_at(index)
        else
            puts "\t\t• #{l.name}".cyan
        end
    end

    return labels
end

# Returns a deduped string of label values by converting the string to an array of
# unique values and converting it back to a string.
def remove_duplicates(labels)
    return labels.split(',').uniq.join(',')
end

# Returns an array of Github issues by fetching issues related to the squad and targeted labels
# that were exported and set at runtime.
def get_github_issues_with_exported_labels(client)
    puts "Fetching Github issues that contain the following exported label(s):"

    labels = remove_duplicates("#{$SQUAD_LABEL},#{$TARGET_LABELS}")
    labels.split(',').each do |label|
        puts "\t• #{label}".cyan
    end

    issues = client.list_issues($BACKLOG, :labels => labels)
    if issues.length == 0
        puts "\nNo issues were found that contained the exported targeted labels: #{labels.split(',')}"
    else
        puts "\nFound #{issues.count} issue(s) that contained the exported targeted label(s):"
        issues.each do |issue|
            puts "\t• #{issue.html_url} - #{issue.title}".blue
        end
    end

    return issues
end

# Remove a list of labels from the targeted Github issue.
def removing_labels_from_github_issue(client, issue, labels)
    puts "\t• Removing the following labels from the github issue: #{labels}"
    labels.each do |label|
        client.remove_label("stolostron/backlog", issue.number, label)
    end
end

def main(client)
    issues = get_github_issues_with_exported_labels(client)
    issues.each do |issue|
        labels = check_github_issue_for_missing_labels(issue, $REPLACEMENT_LABELS.split(','))
    
        add_labels_to_github_issue(client, issue, labels)
        removing_labels_from_github_issue(client, issue, $TARGET_LABELS.split(','))
    end
end

main(client)
