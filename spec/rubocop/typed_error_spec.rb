# frozen_string_literal: true

require "rubocop"
require "browserctl/rubocop/cops/typed_error"

RSpec.describe RuboCop::Cop::Browserctl::TypedError do
  let(:cop) { described_class.new(RuboCop::Config.new) }

  def offenses_for(source)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f)
    commissioner = RuboCop::Cop::Commissioner.new([cop], [], raise_error: true)
    commissioner.investigate(processed_source).offenses
  end

  it "accepts a raise of a typed Browserctl subclass with no explicit code" do
    expect(offenses_for(<<~RUBY)).to be_empty
      raise Browserctl::SelectorNotFound, "no such selector"
    RUBY
  end

  it "accepts a raise with code: pointing at a Codes constant" do
    expect(offenses_for(<<~RUBY)).to be_empty
      raise Browserctl::Error, "expired",
            code: Browserctl::Error::Codes::STATE_EXPIRED
    RUBY
  end

  it "accepts a raise Browserctl::Error.new(..., code: Codes::...) form" do
    expect(offenses_for(<<~RUBY)).to be_empty
      raise Browserctl::Error.new(
        "expired",
        code: Browserctl::Error::Codes::STATE_EXPIRED
      )
    RUBY
  end

  it "flags ANY string literal passed as code:, even a canonical SCREAMING_SNAKE one" do
    # Tightened in v0.14 WS-1 PR 5: every `code:` must be a Codes constant so
    # renames in the enum propagate. No stale whitelist of allowed strings.
    offenses = offenses_for(<<~RUBY)
      raise Browserctl::Error, "auth", code: "AUTH_REQUIRED"
    RUBY
    expect(offenses.size).to eq(1)
    expect(offenses.first.message).to include("string literal \"AUTH_REQUIRED\"")
  end

  it "flags a non-canonical string literal in code:" do
    offenses = offenses_for(<<~RUBY)
      raise Browserctl::Error, "boom", code: "state_expired"
    RUBY
    expect(offenses.size).to eq(1)
    expect(offenses.first.message).to include("string literal \"state_expired\"")
  end

  it "flags a string literal in the .new(..., code:) shape too" do
    offenses = offenses_for(<<~RUBY)
      raise Browserctl::Error.new("boom", code: "STATE_EXPIRED")
    RUBY
    expect(offenses.size).to eq(1)
    expect(offenses.first.message).to include("string literal \"STATE_EXPIRED\"")
  end

  it "ignores plain Ruby raises that are not Browserctl errors" do
    expect(offenses_for(<<~RUBY)).to be_empty
      raise ArgumentError, "bad arg"
      raise "ad hoc"
    RUBY
  end
end
