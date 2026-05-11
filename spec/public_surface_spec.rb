# frozen_string_literal: true

# Public surface lock-file (v0.14 WS-4 PR 11).
#
# Locks the three surfaces documented as Stable in
# docs/reference/api-stability.md:
#
#   1. CLI top-level commands  — discovered by parsing the `when "<name>"`
#      lines in bin/browserctl. Top-level nouns only; subcommands of
#      `page`, `state`, `cookie`, etc. are out of scope here because they
#      live inside their own dispatcher classes under
#      lib/browserctl/commands/.
#   2. Browserctl::Client public instance methods.
#   3. Browserctl::PageProxy public instance methods (the workflow DSL
#      page object; api-stability.md refers to it as "PageProxy").
#
# Any drift fails the spec with a diff naming the extras (added or
# renamed in code) and the misses (removed from code). Intentional
# changes update spec/fixtures/public_surface.yml in the same PR.

require "spec_helper"
require "yaml"
require "browserctl/workflow"

RSpec.describe "public surface lock-file" do
  fixture_path = File.expand_path("fixtures/public_surface.yml", __dir__)
  bin_path     = File.expand_path("../bin/browserctl", __dir__)

  let(:fixture_path) { fixture_path }
  let(:bin_path)     { bin_path }
  let(:expected)     { YAML.load_file(fixture_path) }

  def public_methods_for(klass)
    (klass.public_instance_methods - Object.public_instance_methods)
      .map(&:to_s).sort
  end

  def cli_top_level_commands
    src = File.read(bin_path)
    src.scan(/^\s*when\s+"([a-z][a-z0-9-]*)"/).flatten.uniq.sort
  end

  def diff_message(label, actual, expected)
    extra   = actual   - expected
    missing = expected - actual
    <<~MSG
      public_surface.yml drift detected for #{label}.
        extra (added or renamed in code):   #{extra.inspect}
        missing (removed from code):        #{missing.inspect}
      If this change is intentional, update spec/fixtures/public_surface.yml in the same commit.
    MSG
  end

  it "matches Browserctl::Client public methods" do
    actual = public_methods_for(Browserctl::Client)
    expect(actual).to eq(expected.fetch("client").sort),
                      -> { diff_message("client", actual, expected.fetch("client").sort) }
  end

  it "matches Browserctl::PageProxy public methods" do
    actual = public_methods_for(Browserctl::PageProxy)
    expect(actual).to eq(expected.fetch("page_proxy").sort),
                      -> { diff_message("page_proxy", actual, expected.fetch("page_proxy").sort) }
  end

  it "matches the bin/browserctl top-level command dispatch table" do
    actual = cli_top_level_commands
    expect(actual).to eq(expected.fetch("cli_commands").sort),
                      -> { diff_message("cli_commands", actual, expected.fetch("cli_commands").sort) }
  end
end
