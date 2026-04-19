# frozen_string_literal: true

require_relative "workflow"
require_relative "client"

module Browserctl
  class Runner
    SEARCH_PATHS = [
      "./.browserctl/workflows",
      File.expand_path("~/.browserctl/workflows")
    ].freeze

    def run_workflow(name, **params)
      defn    = fetch_workflow(name)
      results = defn.call(params, Client.new)
      print_results(results)
      results.all?(&:ok)
    end

    def list_workflows
      load_all_workflows
      REGISTRY.map { |name, defn| { name: name, desc: defn.description } }
    end

    def describe_workflow(name)
      defn = fetch_workflow(name)
      { name: defn.name, desc: defn.description, params: format_params(defn), steps: defn.steps.map(&:first) }
    end

    private

    def fetch_workflow(name)
      load_workflow_file(name)
      REGISTRY[name.to_s] || raise("workflow '#{name}' not found")
    end

    def load_workflow_file(name)
      return if REGISTRY.key?(name.to_s)

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
