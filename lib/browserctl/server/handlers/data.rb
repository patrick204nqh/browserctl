# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      # `data` is the unified verb family that subsumes `cookie *` and
      # `storage *` (introduced in v0.15 via ADR-0021). Every operation takes
      # a required `scope` ∈ {cookies, localStorage, sessionStorage} and
      # returns a unified envelope shape — see docs/reference/commands.md
      # for the full table.
      #
      # The legacy `cookies`, `set_cookie`, `delete_cookies`, `import_cookies`,
      # `storage_*` handlers remain as aliases that delegate here so the old
      # wire verbs keep working for the v0.15 deprecation window.
      module Data
        VALID_SCOPES = %w[cookies localStorage sessionStorage].freeze

        # Short-form scope aliases. Were accepted as v0.15-only wire aliases
        # per ADR-0021; removed in v0.16. Kept here only to produce a helpful
        # hint in the INVALID_ARGUMENT envelope.
        SHORT_FORM_HINTS = { "local" => "localStorage", "session" => "sessionStorage" }.freeze

        private

        # @return [Hash] unified response with `ok`, `scope`, plus per-op fields
        def cmd_data_get(req)
          scope = validate_scope(req[:scope])
          return scope if scope.is_a?(Hash) # error envelope

          case scope
          when "cookies"
            { error: "data get is not supported for scope 'cookies' — use 'data list'",
              code: Browserctl::Error::Codes::INVALID_ARGUMENT }
          when "localStorage", "sessionStorage"
            with_page(req[:name]) do |session|
              js = storage_get_js(scope, req[:key])
              value = session.driver.evaluate(js)
              { ok: true, scope: scope, key: req[:key], value: value }
            end
          end
        end

        def cmd_data_set(req)
          scope = validate_scope(req[:scope])
          return scope if scope.is_a?(Hash)

          case scope
          when "cookies"
            with_page(req[:name]) do |session|
              unless req[:domain]
                next({ error: "data set --scope cookies requires --domain",
                       code: Browserctl::Error::Codes::INVALID_ARGUMENT })
              end

              session.driver.cookies_set(
                name: req[:key],
                value: req[:value],
                domain: req[:domain],
                path: req.fetch(:path, "/")
              )
              { ok: true, scope: scope, key: req[:key] }
            end
          when "localStorage", "sessionStorage"
            with_page(req[:name]) do |session|
              js = storage_set_js(scope, req[:key], req[:value])
              session.driver.evaluate(js)
              { ok: true, scope: scope, key: req[:key] }
            end
          end
        end

        def cmd_data_delete(req)
          scope = validate_scope(req[:scope])
          return scope if scope.is_a?(Hash)

          case scope
          when "cookies"
            with_page(req[:name]) do |session|
              count = session.driver.cookies_all.length
              session.driver.cookies_clear
              { ok: true, scope: scope, deleted: count }
            end
          when "localStorage"
            with_page(req[:name]) do |session|
              count = JSON.parse(session.driver.evaluate("JSON.stringify({...localStorage})") || "{}").length
              session.driver.evaluate("localStorage.clear()")
              { ok: true, scope: scope, deleted: count }
            end
          when "sessionStorage"
            with_page(req[:name]) do |session|
              count = JSON.parse(session.driver.evaluate("JSON.stringify({...sessionStorage})") || "{}").length
              session.driver.evaluate("sessionStorage.clear()")
              { ok: true, scope: scope, deleted: count }
            end
          end
        end

        def cmd_data_list(req)
          scope = validate_scope(req[:scope])
          return scope if scope.is_a?(Hash)

          case scope
          when "cookies"
            with_page(req[:name]) do |session|
              entries = session.driver.cookies_all.values.map(&:to_h)
              { ok: true, scope: scope, entries: entries, count: entries.length }
            end
          when "localStorage", "sessionStorage"
            with_page(req[:name]) do |session|
              raw     = session.driver.evaluate("JSON.stringify({...#{scope}})") || "{}"
              parsed  = JSON.parse(raw)
              entries = parsed.map { |k, v| { key: k, value: v } }
              { ok: true, scope: scope, entries: entries, count: entries.length }
            end
          end
        end

        # Returns the canonical scope string, or an error envelope on bad input.
        def validate_scope(raw)
          return invalid_scope_error(raw) if raw.nil?

          scope = raw.to_s
          return invalid_scope_error(raw) unless VALID_SCOPES.include?(scope)

          scope
        end

        def invalid_scope_error(raw)
          hint = SHORT_FORM_HINTS[raw.to_s]
          message = "invalid --scope '#{raw}' — expected one of: #{VALID_SCOPES.join(', ')}"
          message += " (short form '#{raw}' was removed in v0.16 — use '#{hint}')" if hint
          {
            error: message,
            code: Browserctl::Error::Codes::INVALID_ARGUMENT
          }
        end

        def storage_get_js(scope, key)
          target = scope == "localStorage" ? "localStorage" : "sessionStorage"
          "#{target}.getItem(#{key.to_json})"
        end

        def storage_set_js(scope, key, value)
          target = scope == "localStorage" ? "localStorage" : "sessionStorage"
          "#{target}.setItem(#{key.to_json}, #{value.to_json})"
        end
      end
    end
  end
end
