# frozen_string_literal: true

module Browserctl
  module SecretResolvers
    class Base
      def self.scheme
        raise NotImplementedError, "#{name}.scheme not implemented"
      end

      def available? = true

      def resolve(_reference)
        raise NotImplementedError, "#{self.class.name}#resolve not implemented"
      end
    end
  end
end
