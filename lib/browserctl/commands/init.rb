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

      def self.run(_args)
        FileUtils.mkdir_p(".browserctl/workflows")
        FileUtils.touch(".browserctl/workflows/.keep")

        config_path = ".browserctl/config.yml"
        unless File.exist?(config_path)
          File.write(config_path, CONFIG_TEMPLATE)
        end

        puts "Initialised browserctl project:"
        puts "  .browserctl/workflows/   (place workflow .rb files here)"
        puts "  .browserctl/config.yml   (project settings)"
      end
    end
  end
end
