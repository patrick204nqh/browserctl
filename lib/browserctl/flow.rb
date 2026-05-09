# frozen_string_literal: true

require_relative "errors"

module Browserctl
  FlowParamDef    = Struct.new(:name, :required, :secret, :default, :secret_ref, keyword_init: true)
  FlowStepDef     = Struct.new(:label, :block, :retry_count, :timeout, keyword_init: true)
  FlowConditionDef = Struct.new(:kind, :label, :block, keyword_init: true)

  class Flow
    SEMVER_RE = /\A\d+\.\d+\.\d+\z/

    attr_reader :name,
                :version_string,
                :description,
                :param_defs,
                :steps,
                :preconditions,
                :postconditions,
                :produces_state_block,
                :min_browserctl_version

    def initialize(name)
      @name                   = name.to_s
      @version_string         = "0.0.0"
      @description            = nil
      @param_defs             = {}
      @steps                  = []
      @preconditions          = []
      @postconditions         = []
      @produces_state_block   = nil
      @min_browserctl_version = nil
    end

    def version(value)
      validate_semver!(value, label: "version")
      @version_string = value.to_s
    end

    def requires_browserctl(value)
      validate_semver!(value, label: "requires_browserctl")
      @min_browserctl_version = value.to_s
    end

    def desc(text)
      @description = text.to_s
    end

    def param(name, required: false, secret: false, default: nil, secret_ref: nil)
      secret = true if secret_ref
      @param_defs[name] = FlowParamDef.new(
        name: name,
        required: required,
        secret: secret,
        default: default,
        secret_ref: secret_ref
      )
    end

    def step(label, retry_count: 0, timeout: nil, &block)
      raise ArgumentError, "flow step '#{label}' requires a block" unless block

      @steps << FlowStepDef.new(label: label, block: block, retry_count: retry_count, timeout: timeout)
    end

    def precondition(label = "precondition", &block)
      raise ArgumentError, "precondition '#{label}' requires a block" unless block

      @preconditions << FlowConditionDef.new(kind: :precondition, label: label, block: block)
    end

    def postcondition(label = "postcondition", &block)
      raise ArgumentError, "postcondition '#{label}' requires a block" unless block

      @postconditions << FlowConditionDef.new(kind: :postcondition, label: label, block: block)
    end

    def produces_state(&block)
      raise ArgumentError, "produces_state requires a block" unless block

      @produces_state_block = block
    end

    private

    def validate_semver!(value, label:)
      return if value.to_s.match?(SEMVER_RE)

      raise ArgumentError, "#{label} must be MAJOR.MINOR.PATCH (got #{value.inspect})"
    end
  end

  def self.flow(name, &block)
    raise ArgumentError, "Browserctl.flow requires a block" unless block

    Flow.new(name).tap { |f| f.instance_exec(&block) }
  end
end
