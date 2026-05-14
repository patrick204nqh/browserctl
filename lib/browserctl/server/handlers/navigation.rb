# frozen_string_literal: true

require "json"
require "timeout"

module Browserctl
  class CommandDispatcher
    module Handlers
      module Navigation
        private

        def cmd_navigate(req)
          unless Policy.allowed_navigation?(req[:url].to_s)
            return error_payload(
              code: Browserctl::Error::Codes::DOMAIN_NOT_ALLOWED,
              message: "navigation to '#{req[:url]}' blocked by domain policy",
              context: { url: req[:url].to_s }
            )
          end

          with_page(req[:name]) do |session|
            session.driver.go_to(req[:url])
            { ok: true, url: session.driver.current_url, challenge: Detectors.cloudflare?(session.driver) }
          end
        end

        def cmd_wait(req)
          with_page(req[:name]) do |session|
            result = wait_for_selector(session.driver, req[:selector], req.fetch(:timeout, 30).to_f)
            result[:error] ? result : { ok: true, selector: req[:selector] }
          end
        end

        def cmd_evaluate(req)
          with_page(req[:name]) { |session| { ok: true, result: session.driver.evaluate(req[:expression]) } }
        end

        def cmd_fill(req)
          with_page(req[:name]) do |session|
            sel = resolve_selector_from(session, req)
            return sel if sel.is_a?(Hash)

            result = type_into(session.driver, sel, req[:value])
            enrich_with_recording_metadata(result, session, sel, req)
          end
        end

        def cmd_click(req)
          with_page(req[:name]) do |session|
            sel = resolve_selector_from(session, req)
            return sel if sel.is_a?(Hash)

            result = click_element(session.driver, sel)
            enrich_with_recording_metadata(result, session, sel, req)
          end
        end

        # Adds ref / fingerprint / snapshot_id / postcondition_hint to a successful
        # click/fill response. Recording uses these to build a self-healing log.
        # When req[:capture_post_snapshot] is true, also takes a fresh snapshot
        # and attaches its digest so workflow run --check can diff DOM state
        # against the recorded baseline.
        def enrich_with_recording_metadata(result, session, selector, req)
          return result unless result[:ok]

          ref = req[:ref] || session.ref_registry.invert[selector]
          fp  = (ref && session.fingerprint_index[ref]) || session.fingerprint_index[selector]
          enriched = result.merge(
            ref: ref,
            fingerprint: fp,
            snapshot_id: session.snapshot_id,
            postcondition_hint: { url: session.driver.current_url }
          )
          enriched[:post_snapshot_digest] = capture_post_snapshot_digest(session) if req[:capture_post_snapshot]
          enriched.compact
        end

        def capture_post_snapshot_digest(session)
          snapshot = @snapshot_builder.call(session.driver)
          Browserctl::Replay::SnapshotDiff.digest(snapshot)
        rescue JSON::ParserError, Timeout::Error, Browserctl::Error => e
          Browserctl.logger.debug("post-snapshot digest skipped: #{e.class}: #{e.message}")
          nil
        end

        def cmd_url(req)
          with_page(req[:name]) { |session| { ok: true, url: session.driver.current_url } }
        end

        def type_into(driver, selector, value)
          el = driver.at_css(selector)
          unless el
            return error_payload(
              code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND,
              message: "selector not found: #{selector}",
              context: { selector: selector }
            )
          end

          el.focus
          el.evaluate("this.select()")
          el.type(value)
          { ok: true }
        end

        def click_element(driver, selector)
          el = driver.at_css(selector)
          unless el
            return error_payload(
              code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND,
              message: "selector not found: #{selector}",
              context: { selector: selector }
            )
          end

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

        def wait_for_selector(driver, selector, timeout)
          deadline = Time.now + timeout
          loop do
            found = driver.at_css(selector)
            break { ok: true } if found
            break { error: "wait timeout: selector '#{selector}' not found after #{timeout}s" } if Time.now >= deadline

            sleep 0.2
          end
        end
      end
    end
  end
end
