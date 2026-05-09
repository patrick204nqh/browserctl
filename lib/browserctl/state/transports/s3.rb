# frozen_string_literal: true

require "open3"
require_relative "../transport"

module Browserctl
  module State
    module Transports
      # S3 transport — shells out to the `aws` CLI so we don't drag the
      # aws-sdk gem into core. URIs look like `s3://bucket/path/key.bctl`.
      # Credentials/region come from the user's normal AWS environment
      # (env vars, `~/.aws/credentials`, IAM, etc.).
      class S3 < Transport::Base
        def self.scheme = "s3"

        def available?
          system("which", "aws", out: ::File::NULL, err: ::File::NULL)
        end

        def read(parsed)
          run!("aws", "s3", "cp", parsed.to_s, "-", binmode: true)
        end

        def write(parsed, blob)
          out, err, status = Open3.capture3("aws", "s3", "cp", "-", parsed.to_s, stdin_data: blob, binmode: true)
          return if status.success?

          raise Transport::TransportError, "aws s3 cp failed: #{err.strip.empty? ? out : err}"
        end

        def run!(*cmd, binmode: false)
          out, err, status = Open3.capture3(*cmd, binmode: binmode)
          return out if status.success?

          raise Transport::TransportError, "#{cmd.first} failed: #{err.strip.empty? ? out : err}"
        end
      end
    end
  end
end

Browserctl::State::Transport.register(Browserctl::State::Transports::S3.new)
