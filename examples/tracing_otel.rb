# frozen_string_literal: true

# Example: wire browserctl's tracing seam to an OpenTelemetry exporter.
#
# This file is doc-only — it is NOT required by the gem, and OpenTelemetry
# is NOT a runtime dependency. Add `opentelemetry-sdk` and an exporter to
# your own application's Gemfile if you want this wiring.
#
# Usage (from a host app, before any browserctl commands are dispatched):
#
#   require "opentelemetry/sdk"
#   require "opentelemetry/exporter/otlp"
#   require "browserctl"
#   require_relative "path/to/tracing_otel"
#
#   Browserctl::Tracing.backend = OtelTracingBackend.new
#
# Every command dispatched by the daemon will then emit a span named
# `command.<cmd>` with `command`, `page`, and `duration_ms` attributes.

require "opentelemetry/sdk"

# Adapter from browserctl's Backend contract to the OpenTelemetry Ruby API.
class OtelTracingBackend
  def initialize(tracer_name: "browserctl", version: Browserctl::VERSION)
    @tracer = OpenTelemetry.tracer_provider.tracer(tracer_name, version)
  end

  def start_span(name, attributes: {})
    @tracer.start_span(name, attributes: stringify(attributes))
  end

  def end_span(span, status:, attributes: {})
    return if span.nil?

    attributes.each { |k, v| span.set_attribute(k.to_s, v) unless v.nil? }
    span.status = OpenTelemetry::Trace::Status.error if status == :error
    span.finish
  end

  private

  def stringify(attrs)
    attrs.each_with_object({}) { |(k, v), h| h[k.to_s] = v unless v.nil? }
  end
end
