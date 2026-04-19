module Browserctl
  module Commands
    class Fill
      def self.run(client, args)
        name, selector, value = args
        abort "usage: browserctl fill <page> <selector> <value>" unless name && selector && value
        puts client.fill(name, selector, value).to_json
      end
    end
  end
end
