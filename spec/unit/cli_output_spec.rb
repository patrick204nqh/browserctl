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
      out, = capture_io { host.print_result(ok: true, value: 42) }
      expect(out).to include('"ok":true')
      expect(out).to include('"value":42')
    end

    it "exits 7 with the body still printed for AUTH_REQUIRED" do
      out, = capture_io do
        expect { host.print_result(error: "login", code: "AUTH_REQUIRED", suggested_flow: "f") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(7) }
      end
      expect(out).to include('"code":"AUTH_REQUIRED"')
      expect(out).to include('"suggested_flow":"f"')
    end

    it "exits 1 for plain errors" do
      capture_io do
        expect { host.print_result(error: "oops") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end

    it "emits a structured JSON line on stderr after the human line" do
      _, err = capture_io do
        expect do
          host.print_result(
            error: "selector not found: .x",
            code: Browserctl::Error::Codes::SELECTOR_NOT_FOUND,
            context: { selector: ".x" },
            suggested_action: "Re-run snapshot."
          )
        end.to raise_error(SystemExit)
      end
      lines = err.split("\n")
      expect(lines.first).to start_with("Error: selector not found")
      payload = JSON.parse(lines.last)
      expect(payload).to eq(
        "code" => "SELECTOR_NOT_FOUND",
        "message" => "selector not found: .x",
        "context" => { "selector" => ".x" },
        "suggested_action" => "Re-run snapshot."
      )
    end

    it "fills in suggested_action and GENERIC code when missing from the daemon response" do
      _, err = capture_io do
        expect { host.print_result(error: "boom") }.to raise_error(SystemExit)
      end
      payload = JSON.parse(err.split("\n").last)
      expect(payload["code"]).to eq("GENERIC")
      expect(payload["suggested_action"]).to eq(Browserctl::Error::SuggestedActions::DEFAULT)
    end
  end

  def capture_io
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end
