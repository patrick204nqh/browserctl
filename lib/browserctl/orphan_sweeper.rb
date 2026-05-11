# frozen_string_literal: true

module Browserctl
  # Terminates orphaned Ferrum-spawned browser processes left behind by previous
  # daemon or rspec runs that did not shut down cleanly (SIGKILL, OOM, crash).
  #
  # Only targets processes whose argv contains the Ferrum temp user-data-dir marker
  # AND whose PPID is 1 — so children of any live daemon are never touched.
  module OrphanSweeper
    USER_DATA_DIR_MARKER = "ferrum_user_data_dir_"

    module_function

    def sweep(logger: Browserctl.logger, lister: method(:list_processes), killer: method(:kill_process))
      return unless supported_platform?

      orphans = find_orphans(lister.call)
      return if orphans.empty?

      logger&.info("orphan sweep: found #{orphans.size} stale browser process(es) from previous run")
      orphans.each { |pid| killer.call(pid, logger) }
    end

    def find_orphans(processes)
      processes.filter_map do |p|
        next unless p[:ppid] == 1 && p[:command].to_s.include?(USER_DATA_DIR_MARKER)

        p[:pid]
      end
    end

    def list_processes
      output = `ps -eo pid=,ppid=,command= 2>/dev/null`
      return [] if output.empty?

      output.lines.filter_map do |line|
        pid, ppid, command = line.strip.split(" ", 3)
        next unless pid && ppid && command

        { pid: pid.to_i, ppid: ppid.to_i, command: command }
      end
    end

    def kill_process(pid, logger)
      Process.kill("TERM", pid)
      logger&.info("orphan sweep: terminated PID #{pid}")
    rescue Errno::ESRCH
      # already gone
    rescue Errno::EPERM
      logger&.debug("orphan sweep: no permission to kill PID #{pid}")
    end

    def supported_platform?
      !RUBY_PLATFORM.match?(/mingw|mswin|windows/)
    end
  end
end
