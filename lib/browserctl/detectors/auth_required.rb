# frozen_string_literal: true

module Browserctl
  module Detectors
    # Detects "you need to log in again" — the signal that flips a workflow's
    # `load_state` into `state rotate` territory. Lives alongside the older
    # `Detectors.cloudflare?` and follows the same `(page) -> Result` shape.
    #
    # Three independent checks, evaluated in order. The first to fire wins:
    #
    #   1. URL → login path. The page is currently sitting on /login,
    #      /signin, /auth/login, or a similar canonical login route. This
    #      catches redirect-based auth ("we noticed you're not logged in").
    #   2. Recent HTTP 401 / 403. The most recent network response on this
    #      page was an auth challenge from the backend.
    #   3. Cookie ledger. A caller-supplied list of cookies contains entries
    #      that have already expired. Useful when the daemon is preflighting
    #      a bundle before navigating.
    #
    # Each check is pure — no daemon dependencies — so the same detector
    # runs server-side (handlers/observation.rb) and client-side (workflow
    # `load_state` hook).
    module AuthRequired
      Result = Struct.new(:triggered, :code, :reason, :suggested_flow, keyword_init: true) do
        def to_h
          { triggered: triggered, code: code, reason: reason, suggested_flow: suggested_flow }.compact
        end
      end

      LOGIN_PATH_RE = %r{(?:^|/)(login|signin|sign[-_]in|auth/(?:login|signin)|account/login)(?:/|$|\?)}i

      AUTH_HTTP_STATUSES = [401, 403].freeze

      class << self
        # Run every check; return the first triggered Result, or a non-
        # triggered Result if all pass.
        #
        # @param page  [#current_url] anything quacking like a Page
        # @param recent_responses [Array<Hash>] each `{ status:, url: }`; the
        #   caller is responsible for collecting these (e.g. via Ferrum's
        #   network.traffic). Empty by default so callers without traffic
        #   instrumentation still get the URL/cookie checks.
        # @param cookies [Array<Hash>, nil] each `{ name:, expires: }`;
        #   `expires` is a unix timestamp. nil to skip the cookie check.
        # @param suggested_flow [String, nil] flow name to surface when the
        #   detector fires — populated by callers from the bundle manifest.
        # @return [Result]
        def detect(page, recent_responses: [], cookies: nil, suggested_flow: nil)
          [
            check_url(page, suggested_flow),
            check_responses(recent_responses, suggested_flow),
            check_cookies(cookies, suggested_flow)
          ].find(&:triggered) || negative
        end

        # Convenience predicate matching the existing `Detectors.cloudflare?`
        # style. Callers that just need a boolean can use this.
        def triggered?(page, **)
          detect(page, **).triggered
        end

        private

        def check_url(page, suggested_flow)
          url = safe_call(page, :current_url).to_s
          match = LOGIN_PATH_RE.match(url)
          return negative unless match

          Result.new(triggered: true, code: "redirect_login",
                     reason: "url '#{url}' matches login path", suggested_flow: suggested_flow)
        end

        def check_responses(recent_responses, suggested_flow)
          response = Array(recent_responses).reverse_each.find do |r|
            AUTH_HTTP_STATUSES.include?(r[:status] || r["status"])
          end
          return negative unless response

          status = response[:status] || response["status"]
          url    = response[:url] || response["url"]
          Result.new(triggered: true, code: "http_#{status}",
                     reason: "recent #{status} from #{url}", suggested_flow: suggested_flow)
        end

        def check_cookies(cookies, suggested_flow)
          return negative if cookies.nil?

          expired = expired_cookies(cookies)
          return negative if expired.empty?

          names = expired.map { |c| c[:name] || c["name"] }.compact.join(", ")
          Result.new(triggered: true, code: "cookie_expired",
                     reason: "expired cookies: #{names}", suggested_flow: suggested_flow)
        end

        def expired_cookies(cookies)
          now = Time.now.to_f
          Array(cookies).select { |c| cookie_expired?(c, now) }
        end

        def cookie_expired?(cookie, now)
          exp = cookie[:expires] || cookie["expires"]
          return false unless exp

          float = exp.to_f
          float.positive? && float < now
        end

        def negative
          Result.new(triggered: false, code: nil, reason: nil, suggested_flow: nil)
        end

        def safe_call(obj, method)
          obj.respond_to?(method) ? obj.public_send(method) : nil
        end
      end
    end

    # Module-level shorthand so callers match the existing `Detectors.cloudflare?` style.
    def self.auth_required?(page, **)
      AuthRequired.triggered?(page, **)
    end

    def self.auth_required(page, **)
      AuthRequired.detect(page, **)
    end
  end
end
