# frozen_string_literal: true

require_relative "../constants"

module Browserctl
  class IdleWatcher
    def initialize(last_used_fn)
      @last_used_fn = last_used_fn
    end

    def watch(server)
      loop do
        sleep 60
        shutdown(server) if idle?
      end
    end

    private

    def idle?
      Time.now - @last_used_fn.call > IDLE_TTL
    end

    def shutdown(server)
      $stdout.puts "browserd idle timeout, shutting down"
      quietly { server.close }
      Process.kill("INT", Process.pid)
    end

    def quietly
      yield
    rescue StandardError
      nil
    end
  end
end
