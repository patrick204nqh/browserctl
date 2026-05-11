# frozen_string_literal: true

require "spec_helper"
require "browserctl/commands/trace"
require "fileutils"
require "stringio"
require "tmpdir"

# Pins the rendered timeline output to a checked-in golden file so the
# extraction refactor (v0.14 WS-3 PR 9) is provably byte-identical to the
# pre-extraction implementation.
RSpec.describe "browserctl trace golden output" do
  let(:fixture)   { File.expand_path("../fixtures/trace/sample.log", __dir__) }
  let(:golden)    { File.expand_path("../fixtures/trace/sample.golden.txt", __dir__) }
  let(:tmp_dir)   { Dir.mktmpdir("browserctl-trace-golden") }

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  it "matches the golden file byte-for-byte" do
    FileUtils.cp(fixture, File.join(tmp_dir, "daemon.log"))
    out = StringIO.new
    err = StringIO.new
    Browserctl::Commands::Trace.run([], log_dir: tmp_dir, out: out, err: err)

    expect(out.string).to eq(File.read(golden))
  end
end
