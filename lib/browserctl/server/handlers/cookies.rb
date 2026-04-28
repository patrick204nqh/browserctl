# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module Cookies
        private

        def cmd_cookies(req)
          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          all = session.page.cookies.all
          { ok: true, cookies: all.values.map(&:to_h) }
        end

        def cmd_set_cookie(req)
          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          session.page.cookies.set(
            name: req[:cookie_name],
            value: req[:value],
            domain: req[:domain],
            path: req.fetch(:path, "/")
          )
          { ok: true }
        end

        def cmd_delete_cookies(req)
          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          session.page.cookies.clear
          { ok: true }
        end

        def cmd_import_cookies(req)
          with_page(req[:name]) do |session|
            req[:cookies].each do |c|
              session.page.cookies.set(
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
