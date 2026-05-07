# frozen_string_literal: true

module Browserctl
  module Driver
    class Base
      def create_page   = raise NotImplementedError, "#{self.class.name}#create_page not implemented"
      def quit          = raise NotImplementedError, "#{self.class.name}#quit not implemented"
      def headed?       = raise NotImplementedError, "#{self.class.name}#headed? not implemented"
      def supports?(_)  = false
      def devtools_info(_page) = raise NotImplementedError, "#{self.class.name}#devtools_info not implemented"
    end
  end
end
