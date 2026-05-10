# frozen_string_literal: true

require "fileutils"
require_relative "../constants"

module Browserctl
  module Workflow
    # Renders a `Browserctl.flow` definition that wraps a promoted workflow.
    # The flow becomes a globally-registered, parameterised handle that runs
    # the underlying workflow via `Runner#run_workflow`. Params are inferred
    # from the workflow's `param_defs` so callers see the same surface area
    # they would on the workflow itself.
    #
    # Wrapping (rather than translating step-by-step) keeps the workflow as
    # the single source of truth: edits to the workflow file flow through
    # to the wrapper without regeneration.
    module FlowWrapper
      module_function

      def target_dir
        File.join(Browserctl::BROWSERCTL_DIR, "flows")
      end

      def target_path(name)
        File.join(target_dir, "#{name}.rb")
      end

      # @param defn [Browserctl::WorkflowDefinition]
      # @return [String] Ruby source for a flow file
      def render(defn)
        params = defn.param_defs.values.map { |p| render_param(p) }.join("\n")
        desc   = defn.description || "Promoted from workflow '#{defn.name}'"
        <<~RUBY
          # frozen_string_literal: true

          require "browserctl/flow"
          require "browserctl/runner"

          # Auto-generated flow wrapper for workflow '#{defn.name}'.
          # Edit the underlying workflow file rather than this wrapper.
          Browserctl.flow(#{defn.name.inspect}) do
            version "1.0.0"
            requires_browserctl "0.11.0"
            desc #{desc.inspect}

          #{params.gsub(/^/, '  ') unless params.empty?}

            step("run workflow #{defn.name}") do
              Browserctl::Runner.new.run_workflow(#{defn.name.inspect}, **params)
            end
          end
        RUBY
      end

      # @param defn [Browserctl::WorkflowDefinition]
      # @param overwrite [Boolean]
      # @param dir [String, nil] override target dir (testing)
      # @return [String] path written
      def write(defn, overwrite: true, dir: nil)
        path = dir ? File.join(dir, "#{defn.name}.rb") : target_path(defn.name)
        if File.exist?(path) && !overwrite
          raise Browserctl::WorkflowError, "flow wrapper already exists at #{path} (pass overwrite: true to replace)"
        end

        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, render(defn))
        path
      end

      def render_param(param)
        opts = []
        opts << "required: true" if param.required
        opts << "secret: true"   if param.secret && !param.secret_ref
        opts << "secret_ref: #{param.secret_ref.inspect}" if param.secret_ref
        opts << "default: #{param.default.inspect}" unless param.default.nil?
        suffix = opts.empty? ? "" : ", #{opts.join(', ')}"
        "param :#{param.name}#{suffix}"
      end
    end
  end
end
