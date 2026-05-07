# frozen_string_literal: true

require "delegate"

module Browserctl
  module Driver
    # Wraps a Ferrum::Page so handlers receive a driver-namespaced object instead of
    # a raw Ferrum type. Currently a transparent delegator — the seam exists so future
    # CDP-specific behaviour (capability checks, instrumentation) can live here without
    # touching every handler. Delete this class if no override lands by the next driver.
    class CDPPage < SimpleDelegator
    end
  end
end
