# frozen_string_literal: true

module Browserctl
  # Pluggable tracing seam shaped like OpenTelemetry's span API, without
  # taking an OpenTelemetry dependency.
  #
  # Backend contract
  # ----------------
  #
  # A tracing backend must respond to two methods:
  #
  #   start_span(name, attributes:) -> span
  #     - `name` is a String (e.g. "command.navigate").
  #     - `attributes` is a Hash of additional span tags.
  #     - Returns an opaque span object that will be passed back to
  #       `end_span`. May return `nil`; `end_span` must tolerate that.
  #
  #   end_span(span, status:, attributes: {})
  #     - `span` is whatever `start_span` returned.
  #     - `status` is `:ok` or `:error`.
  #     - `attributes` carries any tags computed at close time
  #       (notably `duration_ms`). Optional.
  #
  # The default backend is `NoopBackend` — it does nothing. A custom
  # backend is wired in via `Browserctl::Tracing.backend = ...`.
  # The contract is part of the Extension zone — see
  # `docs/reference/api-stability.md`.
  module Tracing
    # No-op default. Implements the Backend contract above.
    class NoopBackend
      def start_span(_name, attributes: {}) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end

      def end_span(_span, status: :ok, attributes: {}) # rubocop:disable Lint/UnusedMethodArgument
        nil
      end
    end

    @backend_mutex = Mutex.new
    @backend = NoopBackend.new

    class << self
      def backend
        @backend_mutex.synchronize { @backend }
      end

      def backend=(value)
        @backend_mutex.synchronize { @backend = value || NoopBackend.new }
      end

      # Wraps a block in a span. Computes `duration_ms` and routes
      # exceptions to `end_span(span, status: :error)`.
      def in_span(name, attributes: {})
        bk = backend
        span = bk.start_span(name, attributes: attributes)
        start = monotonic_ms
        begin
          result = yield
        rescue StandardError
          bk.end_span(span, status: :error, attributes: { duration_ms: monotonic_ms - start })
          raise
        end
        bk.end_span(span, status: :ok, attributes: { duration_ms: monotonic_ms - start })
        result
      end

      private

      def monotonic_ms
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
      end
    end
  end
end
