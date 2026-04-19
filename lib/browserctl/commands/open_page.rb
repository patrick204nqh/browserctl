# frozen_string_literal: true

module Browserctl
  module Commands
    class OpenPage
      def self.run(client, args)
        name = args.shift or abort "usage: browserctl open <name> [--url URL]"
        url  = extract_opt(args, "--url")
        res  = client.open_page(name, url: url)
        puts res.to_json
      end

      def self.extract_opt(args, flag)
        i = args.index(flag)
        return unless i

        args.delete_at(i)
        args.delete_at(i)
      end
    end
  end
end
