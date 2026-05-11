# frozen_string_literal: true

require_relative "../flow_registry"
require_relative "../errors"

module Browserctl
  module State
    # Drives the "rotate this bundle's bound flow and re-save" operation
    # without dragging in CLI input concerns. Extracted from
    # `Browserctl::Commands::State.run_rotate` so the rotation flow is:
    #   - testable without spawning a CLI subprocess
    #   - reusable from Workflow if a workflow ever needs to drive rotation
    #     programmatically.
    #
    # Errors are surfaced by raising typed `Browserctl::FlowError` so the
    # caller (CLI or Workflow) can decide how to render them. The CLI maps
    # to a non-zero exit; a Workflow caller may catch and continue.
    class Mutator
      Result = Struct.new(:save_result, :flow_name, :flow_version, keyword_init: true) do
        def to_h
          (save_result || {}).merge(rotated_flow: flow_name)
        end
      end

      def initialize(client:, registry: Browserctl::FlowRegistry)
        @client   = client
        @registry = registry
      end

      # Re-runs the flow bound to the bundle <name> and re-saves it under the
      # same origins. `params` is the merged param set (file + caller-provided);
      # the CLI does the file/k=v parsing before handing values in.
      #
      # @return [Result]
      # @raise  [Browserctl::FlowError]
      def rotate(name:, params: {}, page: nil)
        manifest = read_manifest!(name)
        flow     = resolve_bound_flow!(manifest)

        flow.run(page: page, client: @client, **params)

        save_result = @client.state_save(name,
                                         flow: flow.name,
                                         flow_version: flow.version_string,
                                         origins: manifest[:origins] || manifest["origins"])
        Result.new(save_result: save_result, flow_name: flow.name, flow_version: flow.version_string)
      end

      private

      def read_manifest!(name)
        info = @client.state_info(name)
        err  = info[:error] || info["error"]
        raise Browserctl::FlowError, err.to_s if err

        info[:info] || info["info"] || {}
      end

      def resolve_bound_flow!(manifest)
        flow_name = manifest[:flow] || manifest["flow"]
        if flow_name.nil? || flow_name.to_s.empty?
          raise Browserctl::FlowError,
                "state has no bound flow — re-save with `state save --flow NAME` first"
        end

        flow = @registry.resolve(flow_name)
        raise Browserctl::FlowError, "flow '#{flow_name}' not found in registry" unless flow

        flow
      end
    end
  end
end
