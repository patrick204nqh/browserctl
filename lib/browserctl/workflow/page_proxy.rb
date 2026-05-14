# frozen_string_literal: true

require_relative "../errors"
require_relative "../replay/fingerprint_matcher"

module Browserctl
  # Per-page wrapper handed to workflow step blocks via `page(:name)`. Forwards
  # one-liners to the daemon `Client`, unwraps the response, and — when a replay
  # context is attached — falls back to fingerprint-based rematching when a
  # selector goes missing.
  #
  # Extracted from `workflow.rb` so the proxy can be loaded and reasoned about
  # independently of the workflow DSL / registry; behaviour is unchanged.
  class PageProxy
    attr_accessor :replay_context

    # Declarative wrapper for `unwrap @client.METHOD(@name, ...)` one-liners.
    # Forwards positional + keyword args verbatim. Pass `extract:` to return
    # a single key from the client response instead of unwrapping.
    def self.delegate_unwrap(method_name, extract: nil)
      if extract
        define_method(method_name) do |*args, **kwargs|
          @client.public_send(method_name, @name, *args, **kwargs)[extract]
        end
      else
        define_method(method_name) do |*args, **kwargs|
          unwrap @client.public_send(method_name, @name, *args, **kwargs)
        end
      end
    end

    def initialize(name, client, replay_context: nil, matcher: nil)
      @name           = name
      @client         = client
      @replay_context = replay_context
      @matcher        = matcher || Replay::FingerprintMatcher.new
    end

    delegate_unwrap :navigate
    delegate_unwrap :snapshot
    delegate_unwrap :screenshot
    delegate_unwrap :wait
    delegate_unwrap :delete_cookies
    delegate_unwrap :press
    delegate_unwrap :storage_set
    delegate_unwrap :dialog_accept
    delegate_unwrap :dialog_dismiss

    delegate_unwrap :devtools,    extract: :devtools_url
    delegate_unwrap :url,         extract: :url
    delegate_unwrap :evaluate,    extract: :result
    delegate_unwrap :storage_get, extract: :value

    def fill(selector = nil, value = nil, ref: nil)
      with_selector_fallback(:fill, selector, ref) do |sel, r|
        @client.fill(@name, sel, value, ref: r)
      end
    end

    def click(selector = nil, ref: nil)
      with_selector_fallback(:click, selector, ref) do |sel, r|
        @client.click(@name, sel, ref: r)
      end
    end

    def hover(selector = nil, ref: nil)
      with_selector_fallback(:hover, selector, ref) do |sel, r|
        @client.hover(@name, sel, ref: r)
      end
    end

    def upload(selector = nil, path = nil, ref: nil)
      with_selector_fallback(:upload, selector, ref) do |sel, r|
        @client.upload(@name, sel, path, ref: r)
      end
    end

    def select(selector = nil, value = nil, ref: nil)
      with_selector_fallback(:select, selector, ref) do |sel, r|
        @client.select(@name, sel, value, ref: r)
      end
    end

    private

    # Issues the wrapped command. If the daemon returns selector_not_found
    # and a replay context has a fingerprint for this selector, takes a
    # fresh snapshot, asks the matcher for a candidate, and retries by ref.
    def with_selector_fallback(cmd, selector, ref)
      res = yield(selector, ref)
      return unwrap(res) if !selector_not_found?(res) || ref || !@replay_context || !selector

      fp = @replay_context.fingerprint_for(selector)
      return unwrap(res) unless fp

      match = @matcher.best(fp, snapshot_entries)
      unless match
        @replay_context.record(command: cmd, selector: selector, reason: "no candidate above threshold")
        return unwrap(res)
      end

      log_rematch(cmd, selector, match)
      @replay_context.record(command: cmd, selector: selector,
                             matched_ref: match.candidate[:ref], score: match.score, reason: "rematch")
      unwrap(yield(nil, match.candidate[:ref]))
    end

    def snapshot_entries
      res = @client.snapshot(@name, format: "elements")
      Array(res[:snapshot])
    end

    def selector_not_found?(res)
      res.is_a?(Hash) && res[:code] == Browserctl::Error::Codes::SELECTOR_NOT_FOUND
    end

    def log_rematch(cmd, selector, match)
      warn "[browserctl replay] #{cmd} selector #{selector.inspect} not found — " \
           "rematched to ref=#{match.candidate[:ref]} (score=#{format('%.2f', match.score)})"
    end

    def unwrap(res)
      raise WorkflowError, res[:error] if res[:error]

      res
    end
  end
end
