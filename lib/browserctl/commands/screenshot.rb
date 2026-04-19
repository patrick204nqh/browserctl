module Browserctl
  module Commands
    class Screenshot
      def self.run(client, args)
        name = args.shift or abort "usage: browserctl shot <page> [--out PATH] [--full]"
        path = extract_opt(args, "--out")
        full = args.delete("--full") ? true : false
        puts client.screenshot(name, path: path, full: full).to_json
      end

      def self.extract_opt(args, flag)
        i = args.index(flag)
        i ? args.delete_at(i) && args.delete_at(i) : nil
      end
    end
  end
end
