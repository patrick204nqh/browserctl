# frozen_string_literal: true

require "open3"
require "tmpdir"
require_relative "../transport"

module Browserctl
  module State
    module Transports
      # 1Password transport — stores bundles as Documents.
      # URIs look like `op://Vault/ItemName`.
      #
      # The op CLI has no streaming primitive for documents, so we stage
      # the blob to a tmpfile (chmod 0600) and use `op document create` /
      # `op document get`.
      class OnePassword < Transport::Base
        SAFE_REF = %r{\Aop://[^/]+/[^/]+\z}

        def self.scheme = "op"

        def available?
          system("which", "op", out: ::File::NULL, err: ::File::NULL)
        end

        def read(parsed)
          uri = parsed.to_s
          validate!(uri)
          out, err, status = Open3.capture3("op", "read", uri, binmode: true)
          return out if status.success?

          raise Transport::TransportError, "op read failed: #{err.strip.empty? ? out : err}"
        end

        def write(parsed, blob)
          uri = parsed.to_s
          validate!(uri)
          vault, title = parse_ref(uri)

          Dir.mktmpdir do |tmp|
            path = ::File.join(tmp, "#{title}.bctl")
            ::File.open(path, "wb", 0o600) { |f| f.write(blob) }

            args = ["op", "document", "create", path, "--title", title, "--vault", vault]
            out, err, status = Open3.capture3(*args)
            unless status.success?
              raise Transport::TransportError, "op document create failed: #{err.strip.empty? ? out : err}"
            end
          end
        end

        def validate!(uri)
          return if SAFE_REF.match?(uri)

          raise Transport::TransportError, "invalid 1Password reference: #{uri.inspect} (expected op://Vault/Item)"
        end

        def parse_ref(uri)
          # op://Vault/Item — exactly two segments after the scheme
          rest = uri.delete_prefix("op://")
          rest.split("/", 2)
        end
      end
    end
  end
end

Browserctl::State::Transport.register(Browserctl::State::Transports::OnePassword.new)
