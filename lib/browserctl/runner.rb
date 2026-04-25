# frozen_string_literal: true

require "json"
require_relative "workflow"
require_relative "client"

module Browserctl
  class Runner
    SEARCH_PATHS = [
      "./.browserctl/workflows",
      File.expand_path("~/.browserctl/workflows")
    ].freeze

    # Runs a named workflow with the given parameters.
    # @param name [String] workflow name (must match /\A[a-zA-Z0-9_-]+\z/)
    # @param params [Hash] keyword arguments passed to the workflow
    # @return [Boolean] true if all steps succeeded
    # @raise [WorkflowError] if the name is invalid or a step fails
    def run_workflow(name, **params)
      defn    = fetch_workflow(name)
      results = defn.call(params, Client.new)
      print_results(results)
      results.all?(&:ok)
    end

    # Lists all registered workflows from the standard search paths.
    # @return [Array<Hash>] array of `{ name:, desc: }` hashes
    def list_workflows
      load_all_workflows
      Browserctl.registry_snapshot.map { |name, defn| { name: name, desc: defn.description } }
    end

    # Returns detailed information about a workflow.
    # @param name [String] workflow name
    # @return [Hash] `{ name:, desc:, params:, steps: }`
    def describe_workflow(name)
      defn = fetch_workflow(name)
      { name: defn.name, desc: defn.description, params: format_params(defn), steps: defn.steps.map(&:label) }
    end

    SAFE_WORKFLOW_NAME = /\A[a-zA-Z0-9_-]+\z/

    def self.load_params_file(path)
      raise "params file not found: #{path}" unless File.exist?(path)

      case File.extname(path).downcase
      when ".yml", ".yaml"
        require "yaml"
        YAML.safe_load_file(path, symbolize_names: true)
      when ".json"
        JSON.parse(File.read(path), symbolize_names: true)
      else
        raise "unsupported params file format: #{path} (use .yml, .yaml, or .json)"
      end
    rescue Psych::SyntaxError => e
      raise "invalid YAML in #{path}: #{e.message}"
    rescue JSON::ParserError => e
      raise "invalid JSON in #{path}: #{e.message}"
    end

    private

    def validate_name!(name)
      return if SAFE_WORKFLOW_NAME.match?(name.to_s)

      raise Browserctl::WorkflowError, "invalid workflow name: #{name.inspect} — use letters, digits, _ and - only"
    end

    def fetch_workflow(name)
      return Browserctl.lookup_workflow(name.to_s) if Browserctl.lookup_workflow(name.to_s)

      validate_name!(name)
      load_workflow_file(name)
      Browserctl.lookup_workflow(name.to_s) || raise("workflow '#{name}' not found")
    end

    def load_workflow_file(name)
      return if Browserctl.lookup_workflow(name.to_s)

      path = workflow_path(name)
      load path if path
    end

    def workflow_path(name)
      SEARCH_PATHS.find do |dir|
        candidate = File.join(dir, "#{name}.rb")
        candidate if File.exist?(candidate)
      end
    end

    def load_all_workflows
      SEARCH_PATHS.select { |d| Dir.exist?(d) }.each { |d| load_from_dir(d) }
    end

    def load_from_dir(dir)
      Dir.glob("#{dir}/*.rb").each do |f|
        load f unless $LOADED_FEATURES.include?(f)
      end
    end

    def print_results(results)
      results.each { |r| print_result(r) }
    end

    def print_result(result)
      label = result.ok ? "[ok]  " : "[fail]"
      msg   = result.ok ? result.name : "#{result.name}: #{result.error}"
      $stdout.puts "  #{label} #{msg}"
    end

    def format_params(defn)
      defn.param_defs.transform_values { |p| { required: p.required, secret: p.secret, default: p.default } }
    end
  end
end
