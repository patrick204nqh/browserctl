# frozen_string_literal: true

require "stringio"
require "browserctl/commands/cli_output"

RSpec.describe Browserctl::Commands::CliOutput do
  let(:host) { Class.new { extend Browserctl::Commands::CliOutput } }

  describe "#exit_code_for" do
    it "returns 7 for AUTH_REQUIRED" do
      expect(host.exit_code_for(error: "x", code: "AUTH_REQUIRED")).to eq(7)
    end

    it "returns 7 for string-keyed AUTH_REQUIRED" do
      expect(host.exit_code_for("error" => "x", "code" => "AUTH_REQUIRED")).to eq(7)
    end

    it "returns 1 for any other error" do
      expect(host.exit_code_for(error: "x", code: "page_not_found")).to eq(1)
      expect(host.exit_code_for(error: "x")).to eq(1)
    end
  end

  describe "#print_result" do
    it "prints OK responses as JSON without exiting" do
      out = capture_stdout { host.print_result(ok: true, value: 42) }
      expect(out).to include('"ok":true')
      expect(out).to include('"value":42')
    end

    it "exits 7 with the body still printed for AUTH_REQUIRED" do
      out = capture_stdout do
        expect { host.print_result(error: "login", code: "AUTH_REQUIRED", suggested_flow: "f") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(7) }
      end
      expect(out).to include('"code":"AUTH_REQUIRED"')
      expect(out).to include('"suggested_flow":"f"')
    end

    it "exits 1 for plain errors" do
      capture_stdout do
        expect { host.print_result(error: "oops") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end

  def capture_stdout
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end
