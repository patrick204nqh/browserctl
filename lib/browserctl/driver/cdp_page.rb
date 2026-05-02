# frozen_string_literal: true

require "delegate"

module Browserctl
  module Driver
    class CDPPage < SimpleDelegator
      # All Ferrum::Page methods delegated automatically.
    end
  end
end
