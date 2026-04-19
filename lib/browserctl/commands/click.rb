module Browserctl
  module Commands
    class Click
      def self.run(client, args)
        name, selector = args
        abort "usage: browserctl click <page> <selector>" unless name && selector
        puts client.click(name, selector).to_json
      end
    end
  end
end
