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

  it "accepts a raise with code: matching a canonical SCREAMING_SNAKE string" do
    expect(offenses_for(<<~RUBY)).to be_empty
      raise Browserctl::Error, "auth", code: "AUTH_REQUIRED"
    RUBY
  end

  it "flags a raise whose explicit code: is a non-canonical string literal" do
    offenses = offenses_for(<<~RUBY)
      raise Browserctl::Error, "boom", code: "state_expired"
    RUBY
    expect(offenses.size).to eq(1)
    expect(offenses.first.message).to include("string literal \"state_expired\"")
  end

  it "ignores plain Ruby raises that are not Browserctl errors" do
    expect(offenses_for(<<~RUBY)).to be_empty
      raise ArgumentError, "bad arg"
      raise "ad hoc"
    RUBY
  end
end
