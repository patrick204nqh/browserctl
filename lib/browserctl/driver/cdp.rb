# frozen_string_literal: true

require "ferrum"
require_relative "base"
require_relative "cdp_page"
require_relative "../errors"

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

        if @browser != "chrome" && (path = resolve_browser_path)
          opts[:browser_path] = path
        end

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
        env_override("CHROMIUM_PATH")
        # Returns nil when no override — Ferrum finds Chromium automatically on most platforms.
      end

      def resolve_brave_path
        override = env_override("BRAVE_PATH")
        return override if override

        platform = detect_platform
        candidates = BRAVE_PATHS.fetch(platform, [])
        path = candidates.find { |p| File.executable?(p) }
        unless path
          raise BrowserNotFound,
                "Brave browser not found. Install Brave or set BRAVE_PATH to its executable."
        end

        path
      end

      def env_override(var)
        value = ENV.fetch(var, nil)
        return nil if value.nil? || value.empty?
        raise BrowserNotFound, "#{var}=#{value} is not an executable file" unless File.executable?(value)

        value
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
