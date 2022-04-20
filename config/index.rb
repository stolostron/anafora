#!/usr/bin/ruby

BEGIN { 
    require 'colorize'
}

module Config
    # Initializing the configuration that is required for the current application
    def self.initialize()
        # Set org and backlog names for issues.
        $ORG = "stolostron"
        $BACKLOG = "#{$ORG}/backlog"

        # Set github user and token.
        $GITHUB_TOKEN = ENV['GITHUB_TOKEN']
        unless $GITHUB_TOKEN
            abort "GITHUB_TOKEN is required to be set to run this application.".red
        end

        # Set the squad label.
        $SQUAD_LABEL=ENV['SQUAD_LABEL']
        unless $SQUAD_LABEL
            abort "SQUAD_LABEL is required to be set. (Export SQUAD_LABEL to filter for the appropriate squad Github issues)".red
        else
            puts "SQUAD_LABEL: #{$SQUAD_LABEL.split(',')}"
        end
    end
end
