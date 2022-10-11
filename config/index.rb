#!/usr/bin/ruby

BEGIN { 
    require 'colorize'
}

module Config
    # Initializing the configuration that is required for the current application
    def self.initialize()
        # Set org and backlog names for issues.
        $ORG = ENV['ORG'] || "stolostron"
        $BACKLOG = ENV['BACKLOG'] || "#{$ORG}/backlog"

        # Set github user and token.
        $GITHUB_TOKEN = ENV['GITHUB_TOKEN']
        unless $GITHUB_TOKEN
            abort "[ERROR] GITHUB_TOKEN is not exported; (GITHUB_TOKEN is required to execute the script)".red
        end

        # Set the squad label.
        $SQUAD_LABEL = ENV['SQUAD_LABEL']
        unless $SQUAD_LABEL
            puts "[WARNING] SQUAD_LABEL is not exported; (SQUAD_LABEL is required to filter squad issues)\n".yellow
    
            puts "Enter label to use for \"SQUAD_LABEL\": (Press ENTER to abort script)"
            $SQUAD_LABEL = gets.chomp
    
            if $SQUAD_LABEL.empty?
                abort "Exiting script...".red
            end
    
            puts "\nSQUAD_LABEL has been set to: #{$SQUAD_LABEL}\n".magenta
        end
    end
end
