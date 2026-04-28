# frozen_string_literal: true

module Browserctl
  class CommandDispatcher
    module Handlers
      module Navigation
        private

        def cmd_navigate(req)
          unless Policy.allowed_navigation?(req[:url].to_s)
            return { error: "navigation to '#{req[:url]}' blocked by domain policy", code: "domain_not_allowed" }
          end

          with_page(req[:name]) do |session|
            session.page.go_to(req[:url])
            { ok: true, url: session.page.current_url, challenge: Detectors.cloudflare?(session.page) }
          end
        end

        def cmd_wait(req)
          with_page(req[:name]) do |session|
            result = wait_for_selector(session.page, req[:selector], req.fetch(:timeout, 30).to_f)
            result[:error] ? result : { ok: true, selector: req[:selector] }
          end
        end

        def cmd_evaluate(req)
          with_page(req[:name]) { |session| { ok: true, result: session.page.evaluate(req[:expression]) } }
        end

        def cmd_fill(req)
          with_page(req[:name]) do |session|
            sel = resolve_selector_from(session, req)
            return sel if sel.is_a?(Hash)

            type_into(session.page, sel, req[:value])
          end
        end

        def cmd_click(req)
          with_page(req[:name]) do |session|
            sel = resolve_selector_from(session, req)
            return sel if sel.is_a?(Hash)

            click_element(session.page, sel)
          end
        end

        def cmd_url(req)
          with_page(req[:name]) { |session| { ok: true, url: session.page.current_url } }
        end

        def type_into(page, selector, value)
          el = page.at_css(selector)
          return { error: "selector not found: #{selector}" } unless el

          el.focus
          el.evaluate("this.select()")
          el.type(value)
          { ok: true }
        end

        def click_element(page, selector)
          el = page.at_css(selector)
          return { error: "selector not found: #{selector}" } unless el

          # Use the DOM native click() so JS-only event listeners fire.
          # CDP mouse simulation (el.click) dispatches events at screen coordinates
          # and misses handlers on elements with no form submit chain.
          el.evaluate("this.click()")
          { ok: true }
        end

        def resolve_selector_from(session, req)
          return req[:selector] if req[:selector]
          return { error: "selector or ref required" } unless req[:ref]

          session.ref_registry[req[:ref]] || { error: "ref '#{req[:ref]}' not found — run snap first" }
        end

        def wait_for_selector(page, selector, timeout)
          deadline = Time.now + timeout
          loop do
            found = page.at_css(selector)
            break { ok: true } if found
            if Time.now >= deadline
              break { error: "wait timeout: selector '#{selector}' not found after #{timeout}s" }
            end

            sleep 0.2
          end
        end
      end
    end
  end
end
