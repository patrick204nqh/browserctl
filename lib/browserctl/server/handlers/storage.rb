# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module Storage
        private

        # Returns { ok: true, value: } or { error: }
        def cmd_storage_get(req)
          with_page(req[:name]) do |session|
            store = req.fetch(:store, "local")
            js    = storage_js_get(store, req[:key])
            return { error: "unknown store '#{store}' — use 'local' or 'session'" } unless js

            value = session.page.evaluate(js)
            { ok: true, value: value }
          end
        end

        # Returns { ok: true } or { error: }
        def cmd_storage_set(req)
          with_page(req[:name]) do |session|
            store = req.fetch(:store, "local")
            js    = storage_js_set(store, req[:key], req[:value])
            return { error: "unknown store '#{store}' — use 'local' or 'session'" } unless js

            session.page.evaluate(js)
            { ok: true }
          end
        end

        # Exports localStorage and/or sessionStorage to a JSON file.
        # Returns { ok: true, path:, key_count: } or { error: }
        def cmd_storage_export(req)
          with_page(req[:name]) do |session|
            stores  = req.fetch(:stores, "all")
            data    = {}

            origin = session.page.evaluate("location.origin")
            data[origin] = {}

            if %w[local all].include?(stores)
              local = JSON.parse(session.page.evaluate("JSON.stringify({...localStorage})") || "{}")
              data[origin].merge!(local)
            end

            if %w[session all].include?(stores)
              sess = JSON.parse(session.page.evaluate("JSON.stringify({...sessionStorage})") || "{}")
              data[origin].merge!(sess)
            end

            path = File.expand_path(req[:path])
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, JSON.generate(data))
            { ok: true, path: path, key_count: data[origin].length }
          end
        end

        # Imports storage keys from a JSON file into the page's localStorage.
        # Returns { ok: true, origins: N, key_count: M } or { error: }
        def cmd_storage_import(req)
          path = File.expand_path(req[:path])
          return { error: "file not found: #{path}" } unless File.exist?(path)

          data = JSON.parse(File.read(path))
          return { error: "invalid storage file format" } unless data.is_a?(Hash)

          with_page(req[:name]) do |session|
            key_count = 0
            data.each do |_origin, keys|
              keys.each do |k, v|
                session.page.evaluate("localStorage.setItem(#{k.to_json}, #{v.to_json})")
                key_count += 1
              end
            end
            { ok: true, origins: data.length, key_count: key_count }
          end
        end

        # Clears localStorage and/or sessionStorage for the page.
        # Returns { ok: true } or { error: }
        def cmd_storage_delete(req)
          with_page(req[:name]) do |session|
            stores = req.fetch(:stores, "all")
            session.page.evaluate("localStorage.clear()")   if %w[local all].include?(stores)
            session.page.evaluate("sessionStorage.clear()") if %w[session all].include?(stores)
            { ok: true }
          end
        end

        def storage_js_get(store, key)
          case store
          when "local"   then "localStorage.getItem(#{key.to_json})"
          when "session" then "sessionStorage.getItem(#{key.to_json})"
          end
        end

        def storage_js_set(store, key, value)
          case store
          when "local"   then "localStorage.setItem(#{key.to_json}, #{value.to_json})"
          when "session" then "sessionStorage.setItem(#{key.to_json}, #{value.to_json})"
          end
        end
      end
    end
  end
end
