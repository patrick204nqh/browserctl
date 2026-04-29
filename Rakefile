# frozen_string_literal: true

# Shared daemon helpers — available to all tasks in rakelib/.

def shutdown_daemon
  system("bundle exec browserctl daemon stop", out: File::NULL, err: File::NULL)
rescue StandardError
  nil
end

def daemon_ready?
  30.times.any? do
    break true if system("bundle exec browserctl daemon ping", out: File::NULL, err: File::NULL)

    sleep 0.5
    false
  end
end

def with_daemon(headed: false)
  shutdown_daemon
  pid = spawn("bundle exec browserd#{' --headed' if headed}")
  abort "browserd did not start within 15 s" unless daemon_ready?
  yield
ensure
  shutdown_daemon
  Process.detach(pid) if pid
end
