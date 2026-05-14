# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module Cookies
        private

        def cmd_cookies(req)
          with_page(req[:name]) do |session|
            all = session.driver.cookies_all
            { ok: true, cookies: all.values.map(&:to_h) }
          end
        end

        def cmd_set_cookie(req)
          with_page(req[:name]) do |session|
            session.driver.cookies_set(
              name: req[:cookie_name],
              value: req[:value],
              domain: req[:domain],
              path: req.fetch(:path, "/")
            )
            { ok: true }
          end
        end

        def cmd_delete_cookies(req)
          with_page(req[:name]) do |session|
            session.driver.cookies_clear
            { ok: true }
          end
        end

        def cmd_import_cookies(req)
          with_page(req[:name]) do |session|
            req[:cookies].each do |c|
              session.driver.cookies_set(
                name: c[:name],
                value: c[:value],
                domain: c[:domain],
                path: c.fetch(:path, "/"),
                httponly: c[:httpOnly] == true,
                secure: c[:secure] == true,
                expires: c[:expires] ? Time.at(c[:expires].to_i) : nil
              )
            end
            { ok: true, count: req[:cookies].length }
          end
        end
      end
    end
  end
end
