# frozen_string_literal: true

require "json"

module Browserctl
  module Commands
    module Status
      def self.run(client)
        ping = client.ping
        pages = client.page_list[:pages] || []
        page_info = pages.map do |name|
          url_res = client.url(name)
          { name: name, url: url_res[:url] || url_res[:error] }
        end

        puts JSON.pretty_generate(
          daemon: "online",
          pid: ping[:pid],
          protocol_version: ping[:protocol_version],
          pages: page_info
        )
      rescue RuntimeError => e
        raise unless e.message.include?("browserd is not running")

        puts JSON.pretty_generate(daemon: "offline", error: e.message)
        exit 1
      end
    end
  end
end
