# frozen_string_literal: true

require "ferrum"
require_relative "base"
require_relative "cdp_page"

module Browserctl
  module Driver
    class CDP < Base
      BRAVE_PATHS = {
        darwin: [
          "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
          File.expand_path("~/Applications/Brave Browser.app/Contents/MacOS/Brave Browser")
        ],
        linux: [
          "/usr/bin/brave-browser",
          "/usr/bin/brave",
          "/snap/bin/brave"
        ],
        windows: [
          "C:/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe",
          "C:/Program Files (x86)/BraveSoftware/Brave-Browser/Application/brave.exe"
        ]
      }.freeze

      def initialize(headless: true, browser: "chrome") # rubocop:disable Lint/MissingSuper
        @headless = headless
        @browser  = browser
        @ferrum   = Ferrum::Browser.new(**ferrum_options)
      end

      def create_page
        CDPPage.new(@ferrum.create_page)
      end

      def quit
        @ferrum.quit
      end

      def headed?
        !@headless
      end

      def supports?(capability)
        capability == :devtools
      end

      def devtools_info(page)
        port      = @ferrum.process.port
        target_id = page.target_id
        { port: port, target_id: target_id }
      end

      private

      def ferrum_options
        opts = {
          timeout: 30,
          process_timeout: 30,
          browser_options: { "disable-dev-shm-usage" => nil, "disable-gpu" => nil }
        }

        opts[:browser_path] = resolve_browser_path if @browser != "chrome"

        if ENV["CI"] || ENV["BROWSERCTL_NO_SANDBOX"]
          Browserctl.logger.warn "no-sandbox enabled (CI or BROWSERCTL_NO_SANDBOX set)"
          opts[:browser_options]["no-sandbox"] = nil
        end

        opts[:headless] = @headless
        opts
      end

      def resolve_browser_path
        case @browser
        when "chromium"
          resolve_chromium_path
        when "brave"
          resolve_brave_path
        else
          raise ArgumentError, "Unknown browser: #{@browser.inspect}"
        end
      end

      def resolve_chromium_path
        ENV["CHROMIUM_PATH"] if ENV["CHROMIUM_PATH"]
        # Ferrum finds Chromium automatically on most platforms; return nil to let it do so
        nil
      end

      def resolve_brave_path
        return ENV["BRAVE_PATH"] if ENV["BRAVE_PATH"]

        platform = detect_platform
        candidates = BRAVE_PATHS.fetch(platform, [])
        path = candidates.find { |p| File.executable?(p) }
        abort "Brave browser not found. Install Brave or set BRAVE_PATH to its executable." unless path

        path
      end

      def detect_platform
        case RUBY_PLATFORM
        when /darwin/              then :darwin
        when /mingw|mswin|windows/ then :windows
        else                            :linux
        end
      end
    end
  end
end
