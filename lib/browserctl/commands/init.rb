# frozen_string_literal: true

require "fileutils"

module Browserctl
  module Commands
    class Init
      CONFIG_TEMPLATE = <<~YAML
        # browserctl project configuration
        # Uncomment and edit to customise.

        # daemon: default          # named daemon instance (see browserd --name)
        # workflows_dir: .browserctl/workflows
      YAML

      GITIGNORE_CONTENT = <<~GITIGNORE
        # Cookie session exports — contain credentials, never commit
        sessions/
      GITIGNORE

      def self.run(_args)
        FileUtils.mkdir_p(".browserctl/workflows")
        FileUtils.touch(".browserctl/workflows/.keep")

        FileUtils.mkdir_p(".browserctl/sessions")

        gitignore_path = ".browserctl/.gitignore"
        File.write(gitignore_path, GITIGNORE_CONTENT) unless File.exist?(gitignore_path)

        config_path = ".browserctl/config.yml"
        File.write(config_path, CONFIG_TEMPLATE) unless File.exist?(config_path)

        puts "Initialised browserctl project:"
        puts "  .browserctl/workflows/   (place workflow .rb files here)"
        puts "  .browserctl/sessions/    (cookie exports — git-ignored)"
        puts "  .browserctl/config.yml   (project settings)"
      end
    end
  end
end
