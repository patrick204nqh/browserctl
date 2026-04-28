# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module Interaction
        private

        def cmd_press(req)
          with_page(req[:name]) do |session|
            session.page.keyboard.down(req[:key])
            session.page.keyboard.up(req[:key])
            { ok: true }
          end
        end

        def cmd_hover(req)
          with_page(req[:name]) do |session|
            coords = session.page.evaluate(
              "(function(sel) {   " \
              "var el = document.querySelector(sel);   " \
              "if (!el) return null;   " \
              "var r = el.getBoundingClientRect();   " \
              "return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; " \
              "})(#{req[:selector].to_json})"
            )
            return { error: "selector not found: #{req[:selector]}" } unless coords

            session.page.mouse.move(x: coords["x"], y: coords["y"])
            { ok: true }
          end
        end

        def cmd_upload(req)
          path = File.expand_path(req[:path])
          return { error: "file not found: #{path}" } unless File.exist?(path)

          with_page(req[:name]) do |session|
            el = session.page.at_css(req[:selector])
            return { error: "selector not found: #{req[:selector]}" } unless el

            el.select_file(path)
            { ok: true }
          end
        end

        def cmd_select(req)
          with_page(req[:name]) do |session|
            el = session.page.at_css(req[:selector])
            return { error: "selector not found: #{req[:selector]}" } unless el

            el.evaluate(
              "this.value = #{req[:value].to_json}; " \
              "this.dispatchEvent(new Event('change', {bubbles: true}))"
            )
            { ok: true }
          end
        end

        def cmd_dialog_accept(req)
          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          text = req[:text]
          id   = nil
          id = session.page.on(:dialog) do |dialog|
            session.page.off(:dialog, id)
            dialog.accept(text)
          end
          { ok: true }
        end

        def cmd_dialog_dismiss(req)
          session = @global_mutex.synchronize { @pages[req[:name]] }
          return { error: "no page named '#{req[:name]}'" } unless session

          id = nil
          id = session.page.on(:dialog) do |dialog|
            session.page.off(:dialog, id)
            dialog.dismiss
          end
          { ok: true }
        end
      end
    end
  end
end
