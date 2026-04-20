# frozen_string_literal: true

module Browserctl
  module Commands
    class Inspect
      def self.run(client, args)
        name = args.shift or abort "usage: browserctl inspect <page>"
        res = client.inspect_page(name)
        if res[:error]
          warn "Error: #{res[:error]}"
          exit 1
        end
        url = res[:devtools_url]
        puts "Opening DevTools for '#{name}':"
        puts "  #{url}"
        opener = RUBY_PLATFORM =~ /darwin/ ? "open" : "xdg-open"
        system(opener, url)
      end
    end
  end
end
