# frozen_string_literal: true

require_relative "../../session"

module Browserctl
  class CommandDispatcher
    module Handlers
      module Session
        private

        # rubocop:disable Metrics/AbcSize
        def cmd_session_save(req)
          first_session = @global_mutex.synchronize { @pages.values.first }
          return { error: "no open pages — open a page before saving a session" } unless first_session

          cookies = first_session.page.cookies.all.values.map(&:to_h)

          pages_meta    = {}
          local_storage = {}
          @global_mutex.synchronize { @pages.dup }.each do |page_name, session|
            session.mutex.synchronize do
              origin    = session.page.evaluate("location.origin")
              local_str = session.page.evaluate("JSON.stringify({...localStorage})")
              pages_meta[page_name] = { url: session.page.current_url, title: session.page.title }
              local_storage[origin] = JSON.parse(local_str)
            end
          end

          Browserctl::Session.save(
            req[:session_name],
            metadata: { version: 1, name: req[:session_name],
                        created_at: Time.now.iso8601, pages: pages_meta },
            cookies: cookies,
            local_storage: local_storage,
            session_storage: {}
          )
          { ok: true, path: Browserctl::Session.path(req[:session_name]),
            pages: pages_meta.length, cookies: cookies.length }
        end
        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def cmd_session_load(req)
          data = Browserctl::Session.load(req[:session_name])

          data[:metadata][:pages].each do |page_name, page_data|
            existing = @global_mutex.synchronize { @pages[page_name.to_s] }
            if existing
              existing.page.go_to(page_data[:url])
            else
              new_page = @browser.create_page
              new_page.go_to(page_data[:url])
              @global_mutex.synchronize { @pages[page_name.to_s] = PageSession.new(new_page) }
            end
          end

          seed_session = @global_mutex.synchronize { @pages.values.first }
          cookie_count = data[:cookies].length
          data[:cookies].each { |c| seed_session.page.cookies.set(**c.slice(:name, :value, :domain, :path)) }

          ls_key_count = 0
          data[:local_storage].each do |origin, keys|
            next if keys.empty?

            tmp_page = @browser.create_page
            tmp_page.go_to(origin)
            keys.each do |k, v|
              tmp_page.evaluate("localStorage.setItem(#{k.to_json}, #{v.to_json})")
              ls_key_count += 1
            end
            tmp_page.close
          end

          { ok: true, cookies: cookie_count, pages: data[:metadata][:pages].length,
            local_storage_keys: ls_key_count }
        rescue RuntimeError => e
          { error: e.message }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def cmd_session_list(_req)
          sessions = Browserctl::Session.all
          { ok: true, sessions: sessions }
        end

        def cmd_session_delete(req)
          Browserctl::Session.delete(req[:session_name])
          { ok: true }
        end
      end
    end
  end
end
