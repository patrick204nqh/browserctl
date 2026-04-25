# frozen_string_literal: true

require "securerandom"

module Browserctl
  class CommandDispatcher
    module Handlers
      module Observation
        private

        def cmd_snapshot(req)
          with_page(req[:name]) { |session| take_snapshot(session, req[:format], req[:diff]) }
        end

        def take_snapshot(session, format, diff)
          nonce     = SecureRandom.hex(8)
          challenge = Detectors.cloudflare?(session.page)

          unless format == "ai"
            return { ok: true, html: session.page.body, challenge: challenge, nonce: nonce }
          end

          snapshot = @snapshot_builder.call(session.page)
          registry = snapshot.to_h { |el| [el[:ref], el[:selector]] }

          prev = session.prev_snapshot
          session.ref_registry  = registry
          session.prev_snapshot = snapshot
          result = diff && prev ? compute_diff(prev, snapshot) : snapshot

          { ok: true, snapshot: result, challenge: challenge, nonce: nonce }
        end

        def compute_diff(prev, current)
          prev_by_sel = prev.to_h { |el| [el[:selector], el] }
          current.reject do |el|
            old = prev_by_sel[el[:selector]]
            old && old.slice(:text, :attrs) == el.slice(:text, :attrs)
          end
        end

        def cmd_screenshot(req)
          with_page(req[:name]) do |session|
            path = safe_screenshot_path(req[:path], req[:name])
            return path if path.is_a?(Hash)

            FileUtils.mkdir_p(File.dirname(path))
            session.page.screenshot(path: path, full: req.fetch(:full, false))
            { ok: true, path: path }
          end
        end

        def safe_screenshot_path(requested, page_name)
          if requested
            expanded = File.expand_path(requested)
            allowed  = SCREENSHOT_ROOTS.any? { |d| expanded.start_with?("#{d}/") || expanded.start_with?(d) }
            return { error: "path outside allowed directory (#{SCREENSHOT_DIR} or project directory)" } unless allowed
            return { error: "invalid extension — use .png, .jpg, or .jpeg" } \
              unless SCREENSHOT_EXTS.include?(File.extname(expanded).downcase)

            expanded
          else
            name_safe = page_name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
            File.join(SCREENSHOT_DIR, "browserctl_shot_#{name_safe}_#{Time.now.to_i}.png")
          end
        end

        def cmd_wait_for(req)
          with_page(req[:name]) do |session|
            wait_for_selector(session.page, req[:selector], req.fetch(:timeout, 10).to_f)
          end
        end

        def cmd_watch(req)
          with_page(req[:name]) do |session|
            result = wait_for_selector(session.page, req[:selector], req.fetch(:timeout, 30).to_f)
            result[:error] ? result : { ok: true, selector: req[:selector] }
          end
        end

        def wait_for_selector(page, selector, timeout)
          deadline = Time.now + timeout
          loop do
            found = page.at_css(selector)
            break { ok: true } if found
            break { error: "wait_for timeout: selector '#{selector}' not found after #{timeout}s" } if Time.now >= deadline

            sleep 0.2
          end
        end
      end
    end
  end
end
