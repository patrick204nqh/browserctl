# frozen_string_literal: true

require_relative "flow"

module Browserctl
  # Discovers and loads flow files from project, user, and bundled stdlib
  # locations. Project flows shadow user flows, which shadow stdlib flows.
  #
  # Files are plain Ruby; loading them is expected to invoke
  # `Browserctl.flow(name) { ... }`, which registers the flow in the global
  # registry. Filename should match the registered name (validated lazily —
  # mismatches are allowed but discouraged).
  class FlowRegistry
    SAFE_NAME = /\A[a-zA-Z0-9_-]+\z/

    # Search order: highest-precedence last so later registrations
    # overwrite earlier ones in the global registry.
    def self.bundled_dir = File.expand_path("flows/stdlib", __dir__)
    def self.user_dir    = File.expand_path("~/.browserctl/flows")
    def self.project_dir = "./.browserctl/flows"

    def self.search_paths
      [bundled_dir, user_dir, project_dir]
    end

    # Loads every flow file from every search path. Lower-precedence dirs
    # run first; project files load last and win on name collisions.
    def self.load_all
      search_paths.each do |dir|
        next unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "*.rb")).each { |f| load f }
      end
      Browserctl.flow_registry_snapshot
    end

    # Resolves a name to a registered flow, loading from disk on demand.
    # Searches in precedence order: project → user → stdlib. The first
    # matching file is loaded and the flow returned via the global registry.
    def self.resolve(name)
      validate_name!(name)
      existing = Browserctl.lookup_flow(name)
      return existing if existing

      search_paths.reverse_each do |dir|
        candidate = File.join(dir, "#{name}.rb")
        next unless File.exist?(candidate)

        load candidate
        flow = Browserctl.lookup_flow(name)
        return flow if flow
      end
      nil
    end

    def self.list
      load_all.map { |n, f| { name: n, desc: f.description, version: f.version_string } }
    end

    def self.validate_name!(name)
      return if SAFE_NAME.match?(name.to_s)

      raise ArgumentError, "invalid flow name: #{name.inspect} — use letters, digits, _ and - only"
    end
  end
end
