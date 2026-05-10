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

            result = type_into(session.page, sel, req[:value])
            enrich_with_recording_metadata(result, session, sel, req)
          end
        end

        def cmd_click(req)
          with_page(req[:name]) do |session|
            sel = resolve_selector_from(session, req)
            return sel if sel.is_a?(Hash)

            result = click_element(session.page, sel)
            enrich_with_recording_metadata(result, session, sel, req)
          end
        end

        # Adds ref / fingerprint / snapshot_id / postcondition_hint to a successful
        # click/fill response. Recording uses these to build a self-healing log.
        def enrich_with_recording_metadata(result, session, selector, req)
          return result unless result[:ok]

          ref = req[:ref] || session.ref_registry.invert[selector]
          fp  = (ref && session.fingerprint_index[ref]) || session.fingerprint_index[selector]
          result.merge(
            ref: ref,
            fingerprint: fp,
            snapshot_id: session.snapshot_id,
            postcondition_hint: { url: session.page.current_url }
          ).compact
        end

        def cmd_url(req)
          with_page(req[:name]) { |session| { ok: true, url: session.page.current_url } }
        end

        def type_into(page, selector, value)
          el = page.at_css(selector)
          return { error: "selector not found: #{selector}", code: "selector_not_found" } unless el

          el.focus
          el.evaluate("this.select()")
          el.type(value)
          { ok: true }
        end

        def click_element(page, selector)
          el = page.at_css(selector)
          return { error: "selector not found: #{selector}", code: "selector_not_found" } unless el

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
            break { error: "wait timeout: selector '#{selector}' not found after #{timeout}s" } if Time.now >= deadline

            sleep 0.2
          end
        end
      end
    end
  end
end
