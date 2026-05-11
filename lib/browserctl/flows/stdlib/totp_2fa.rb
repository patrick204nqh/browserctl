# frozen_string_literal: true

require "openssl"
require_relative "../../flow"

module Browserctl
  module Flows
    # RFC 6238 TOTP code generation from a base32 secret.
    # Pure Ruby; no network and no external gem.
    module TOTP
      module_function

      def generate(secret, at: Time.now, digits: 6, period: 30, digest: "SHA1")
        counter   = (at.to_i / period).to_i
        key       = decode_base32(secret)
        counter_b = [counter].pack("Q>") # 64-bit big-endian
        hmac      = OpenSSL::HMAC.digest(digest, key, counter_b)
        offset    = hmac[-1].ord & 0x0f
        truncated = hmac[offset, 4].unpack1("N") & 0x7fffffff
        truncated.to_s.rjust(digits, "0")[-digits..]
      end

      BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

      def decode_base32(secret)
        cleaned = secret.to_s.upcase.gsub(/[^A-Z2-7]/, "")
        bits = cleaned.each_char.map { |c| char_to_bits(c) }.join
        whole_bytes = bits[0, (bits.length / 8) * 8]
        whole_bytes.scan(/.{8}/).map { |b| b.to_i(2).chr }.join
      end

      def char_to_bits(char)
        idx = BASE32_ALPHABET.index(char) or
          raise Browserctl::Error.new(
            "invalid base32 char #{char.inspect}",
            code: Browserctl::Error::Codes::INVALID_DSL_USAGE,
            context: { char: char }
          )
        idx.to_s(2).rjust(5, "0")
      end
    end
  end
end

Browserctl.flow("totp_2fa") do
  version "1.0.0"
  requires_browserctl "0.11.0"
  desc "Generate an RFC 6238 TOTP code from a base32 secret and type it into the page."

  param :secret,   required: true, secret: true
  param :selector, required: true
  param :digits,   default: 6
  param :period,   default: 30

  precondition("page proxy is present") { !page.nil? }

  step("compute and fill code") do
    code = Browserctl::Flows::TOTP.generate(
      secret,
      digits: digits.to_i,
      period: period.to_i
    )
    page.fill(selector, code)
  end
end
