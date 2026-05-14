# frozen_string_literal: true

require "json"
require_relative "../../state"

module Browserctl
  class CommandDispatcher
    module Handlers
      # Top-level state management — collapses cookies + localStorage +
      # sessionStorage into a single `.bctl` bundle. See lib/browserctl/state.rb.
      module StateRpc
        private

        def cmd_state_save(req)
          first_session = @global_mutex.synchronize { @pages.values.first }
          return { error: "no open pages — open a page before saving state" } unless first_session

          captured, captured_origins = capture_state_payload
          payload = Browserctl::State::Payload.build(
            cookies: captured[:cookies],
            local_storage: captured[:local_storage],
            session_storage: captured[:session_storage],
            origins: req[:origins] || captured_origins,
            flow: req[:flow],
            flow_version: req[:flow_version],
            passphrase: req[:passphrase]
          )
          manifest = Browserctl::State.save(req[:name], payload)

          {
            ok: true,
            path: Browserctl::State.path(req[:name]),
            origins: manifest[:origins],
            cookies: payload.cookies.length,
            encrypted: manifest[:encrypted]
          }
        rescue Browserctl::Error, ArgumentError => e
          { error: e.message }
        end

        def cmd_state_load(req)
          data = Browserctl::State.load(req[:name], passphrase: req[:passphrase])
          target = @global_mutex.synchronize { @pages.values.first }
          return { error: "no open pages — open a page before loading state" } unless target

          cookies = pluck(data[:payload], :cookies, default: [])

          unless req[:skip_auth_check]
            auth = Browserctl::Detectors.auth_required(
              target.driver, cookies: cookies, suggested_flow: data[:manifest][:flow]
            )
            if auth.triggered
              return Browserctl::AuthRequiredError.new(
                auth.reason,
                state: req[:name],
                suggested_flow: auth.suggested_flow,
                reason: auth.reason
              ).to_response
            end
          end

          restore_state_cookies(target, cookies)
          ls_count = restore_local_storage(pluck(data[:payload], :local_storage, default: {}))

          {
            ok: true,
            cookies: cookies.length,
            local_storage_keys: ls_count,
            origins: data[:manifest][:origins]
          }
        rescue Browserctl::State::Bundle::BundleError, Browserctl::Error, ArgumentError, JSON::ParserError => e
          { error: e.message }
        end

        def pluck(hash, sym, default:)
          hash[sym] || hash[sym.to_s] || default
        end

        def restore_state_cookies(target, cookies)
          cookies.each do |raw|
            c = raw.transform_keys(&:to_sym)
            target.driver.cookies_set(**c.slice(:name, :value, :domain, :path))
          end
        end

        def cmd_state_list(_req)
          { ok: true, state: Browserctl::State.all }
        end

        def cmd_state_info(req)
          { ok: true, info: Browserctl::State.info(req[:name]) }
        rescue Browserctl::State::Bundle::BundleError, Browserctl::Error, ArgumentError => e
          { error: e.message }
        end

        def cmd_state_delete(req)
          Browserctl::State.delete(req[:name])
          { ok: true }
        rescue ArgumentError => e
          { error: e.message }
        end

        def capture_state_payload
          first = @global_mutex.synchronize { @pages.values.first }
          cookies = first.driver.cookies_all.values.map(&:to_h)

          local_storage   = {}
          session_storage = {}
          captured_origins = []

          @global_mutex.synchronize { @pages.dup }.each_value do |session|
            session.mutex.synchronize do
              origin    = session.driver.evaluate("location.origin")
              ls_str    = session.driver.evaluate("JSON.stringify({...localStorage})") || "{}"
              ss_str    = session.driver.evaluate("JSON.stringify({...sessionStorage})") || "{}"
              local_storage[origin]   = JSON.parse(ls_str)
              session_storage[origin] = JSON.parse(ss_str)
              captured_origins << origin
            end
          end

          payload = {
            cookies: cookies,
            local_storage: local_storage,
            session_storage: session_storage
          }
          [payload, captured_origins.uniq]
        end

        def restore_local_storage(local_storage)
          count = 0
          local_storage.each do |origin, keys|
            next if keys.nil? || keys.empty?

            tmp_page = @driver.create_page
            begin
              tmp_page.go_to(origin.to_s)
              keys.each do |k, v|
                tmp_page.evaluate("localStorage.setItem(#{k.to_json}, #{v.to_json})")
                count += 1
              end
            ensure
              tmp_page.close
            end
          end
          count
        end
      end
    end
  end
end
