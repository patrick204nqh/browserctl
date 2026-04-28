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

          return { ok: true, html: session.page.body, challenge: challenge, nonce: nonce } unless format == "elements"

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
          return default_screenshot_path(page_name) unless requested

          expanded = File.expand_path(requested)
          return { error: "invalid extension — use .png, .jpg, or .jpeg" } unless valid_screenshot_ext?(expanded)
          return { error: "path outside allowed directory (#{SCREENSHOT_DIR} or project directory)" } \
            unless within_screenshot_roots?(expanded)

          File.join(resolve_dir(File.dirname(expanded)), File.basename(expanded))
        end

        def valid_screenshot_ext?(path)
          SCREENSHOT_EXTS.include?(File.extname(path).downcase)
        end

        def within_screenshot_roots?(path)
          dir = resolve_dir(File.dirname(path))
          SCREENSHOT_ROOTS.any? do |root|
            real_root = resolve_dir(root)
            dir.start_with?("#{real_root}/") || dir == real_root
          end
        end

        def resolve_dir(dir)
          File.realpath(dir)
        rescue Errno::ENOENT
          dir
        end

        def default_screenshot_path(page_name)
          name_safe = page_name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
          File.join(SCREENSHOT_DIR, "browserctl_shot_#{name_safe}_#{Time.now.to_i}.png")
        end
      end
    end
  end
end
