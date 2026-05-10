# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "browserctl/flows/stdlib/cloudflare_solve"

RSpec.describe "stdlib flow: cloudflare_solve" do
  let(:page) { instance_double(Browserctl::PageProxy) }
  let(:client) { instance_double(Browserctl::Client) }

  before do
    Browserctl.flow_registry_reset!
    load File.expand_path("../../../../lib/browserctl/flows/stdlib/cloudflare_solve.rb", __dir__)
  end
  after { Browserctl.flow_registry_reset! }

  let(:flow) { Browserctl.lookup_flow("cloudflare_solve") }

  def silence_stderr
    original = $stderr
    $stderr = StringIO.new
    [yield, $stderr.string]
  ensure
    $stderr = original
  end

  def with_stdin(input)
    original = $stdin
    $stdin = StringIO.new(input)
    yield
  ensure
    $stdin = original
  end

  it "registers under 'cloudflare_solve' with version 1.0.0" do
    expect(flow).to be_a(Browserctl::Flow)
    expect(flow.version_string).to eq("1.0.0")
  end

  describe Browserctl::Flows::CloudflareSolve do
    it "detects via challenge URL" do
      proxy = instance_double(Browserctl::PageProxy,
                              url: "https://example.com/cdn-cgi/challenge-platform/...",
                              evaluate: "")
      expect(described_class.detect?(proxy)).to be true
    end

    it "detects via body signal" do
      proxy = instance_double(Browserctl::PageProxy,
                              url: "https://example.com/",
                              evaluate: "Just a moment...")
      expect(described_class.detect?(proxy)).to be true
    end

    it "returns false on a clean page" do
      proxy = instance_double(Browserctl::PageProxy,
                              url: "https://example.com/dashboard",
                              evaluate: "Welcome back")
      expect(described_class.detect?(proxy)).to be false
    end
  end

  describe "#run" do
    it "raises a precondition error when no challenge is detected" do
      allow(page).to receive_messages(url: "https://x.test/", evaluate: "all clear")

      expect { flow.run(page: page) }
        .to raise_error(Browserctl::FlowPreconditionError, /cloudflare/)
    end

    it "prompts via stderr, waits for stdin, verifies cleared" do
      # Challenge present at first; clear after the human presses Enter.
      url_calls = ["https://x.test/cdn-cgi/challenge-platform/", "https://x.test/dashboard"]
      eval_calls = ["Just a moment...", "Welcome"]
      allow(page).to receive(:url) { url_calls.shift }
      allow(page).to receive(:evaluate) { eval_calls.shift }

      _, out = silence_stderr do
        with_stdin("\n") { flow.run(page: page) }
      end

      expect(out).to include("Cloudflare challenge detected")
    end

    it "raises a step error when challenge is still present after the signal" do
      allow(page).to receive_messages(url: "https://x.test/cdn-cgi/challenge-platform/",
                                      evaluate: "Just a moment...")

      silence_stderr do
        with_stdin("\n") do
          expect { flow.run(page: page) }
            .to raise_error(Browserctl::FlowStepError, /still detected/)
        end
      end
    end

    it "saves the state under state_name when given" do
      url_calls = ["https://x.test/cdn-cgi/challenge-platform/", "https://x.test/dashboard"]
      eval_calls = ["Just a moment...", "Welcome"]
      allow(page).to receive(:url) { url_calls.shift }
      allow(page).to receive(:evaluate) { eval_calls.shift }
      expect(client).to receive(:state_save).with("post_cf").and_return({ ok: true })

      result, = silence_stderr do
        with_stdin("\n") { flow.run(page: page, client: client, state_name: "post_cf") }
      end

      expect(result).to eq(ok: true)
    end

    it "skips state_save when no state_name is given" do
      url_calls = ["https://x.test/cdn-cgi/challenge-platform/", "https://x.test/dashboard"]
      eval_calls = ["Just a moment...", "Welcome"]
      allow(page).to receive(:url) { url_calls.shift }
      allow(page).to receive(:evaluate) { eval_calls.shift }
      expect(client).not_to receive(:state_save)

      result, = silence_stderr do
        with_stdin("\n") { flow.run(page: page, client: client) }
      end

      expect(result).to be_nil
    end

    it "raises when stdin closes before the user signals" do
      allow(page).to receive_messages(url: "https://x.test/cdn-cgi/challenge-platform/",
                                      evaluate: "Just a moment...")

      silence_stderr do
        with_stdin("") do
          expect { flow.run(page: page) }
            .to raise_error(Browserctl::FlowStepError, /stdin closed/)
        end
      end
    end
  end
end
