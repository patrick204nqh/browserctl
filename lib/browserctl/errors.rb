# frozen_string_literal: true

module Browserctl
  class Error < StandardError
    def self.default_code = "error"

    attr_reader :code

    def initialize(msg = nil, code: self.class.default_code)
      @code = code
      super(msg)
    end
  end

  class PageNotFound     < Error; def self.default_code = "page_not_found"     end
  class SelectorNotFound < Error; def self.default_code = "selector_not_found" end
  class RefNotFound      < Error; def self.default_code = "ref_not_found"      end
  class PathNotAllowed   < Error; def self.default_code = "path_not_allowed"   end
  class DomainNotAllowed < Error; def self.default_code = "domain_not_allowed" end
  class TimeoutError     < Error; def self.default_code = "timeout"            end
  class KeyNotFound      < Error; def self.default_code = "key_not_found"      end
end
