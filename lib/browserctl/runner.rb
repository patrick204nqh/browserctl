require_relative "workflow"
require_relative "client"

module Browserctl
  class Runner
    SEARCH_PATHS = [
      "./.browserctl/workflows",
      File.expand_path("~/.browserctl/workflows")
    ].freeze

    def run_workflow(name, **params)
      load_workflow_file(name)

      defn = REGISTRY[name.to_s]
      raise "workflow '#{name}' not found" unless defn

      client  = Client.new
      results = defn.call(params, client)

      results.each do |r|
        if r.ok
          $stdout.puts "  [ok]   #{r.name}"
        else
          $stdout.puts "  [fail] #{r.name}: #{r.error}"
        end
      end

      results.all?(&:ok)
    end

    def list_workflows
      loaded = []
      SEARCH_PATHS.each do |dir|
        next unless Dir.exist?(dir)
        Dir.glob("#{dir}/*.rb").each do |f|
          load f unless $LOADED_FEATURES.include?(f)
          loaded << f
        end
      end
      REGISTRY.map { |name, defn| { name: name, desc: defn.description } }
    end

    def describe_workflow(name)
      load_workflow_file(name)
      defn = REGISTRY[name.to_s]
      raise "workflow '#{name}' not found" unless defn
      {
        name:   defn.name,
        desc:   defn.description,
        params: defn.param_defs.transform_values { |p| { required: p.required, secret: p.secret, default: p.default } },
        steps:  defn.steps.map(&:first)
      }
    end

    private

    def load_workflow_file(name)
      return if REGISTRY.key?(name.to_s)

      SEARCH_PATHS.each do |dir|
        path = File.join(dir, "#{name}.rb")
        if File.exist?(path)
          load path
          return
        end
      end
    end
  end
end
