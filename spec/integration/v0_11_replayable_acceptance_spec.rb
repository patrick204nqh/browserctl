# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require "browserctl/recording"
require "browserctl/runner"
require "browserctl/workflow"
require "browserctl/workflow/promoter"
require "browserctl/workflow/promotion_ledger"
require "browserctl/replay/context"

# v0.11 acceptance: the replayable loop closes.
#
# These specs exercise the full pipeline (record → generate → check ×N →
# promote --as-flow → invoke) without driving a real browser. The browser
# interactions themselves are covered by integration specs elsewhere; the
# v0.11 contribution is the *pipeline* — that the four CLI commands compose
# into a coherent loop, that the ledger gates promotion correctly, and that
# drift is reported as data, not failure.
#
# Client is stubbed because the v0.11 pipeline does not depend on a live
# browser to be tested — every transition (recording log → workflow file →
# verdict → ledger entry → promotion → flow registration) is observable
# from disk and from in-memory registries.
RSpec.describe "v0.11 replayable acceptance" do
  let(:fake_client) { instance_double(Browserctl::Client) }

  around do |example|
    Dir.mktmpdir do |dir|
      @tmp        = dir
      @recordings = File.join(dir, "recordings")
      @state_file = File.join(dir, "active_recording")
      @workflows  = File.join(dir, "workflows")
      @target     = File.join(dir, "user")
      @ledger     = File.join(dir, "check_ledger.jsonl")
      @flow_dir   = File.join(dir, "flows")
      FileUtils.mkdir_p(@recordings)
      FileUtils.mkdir_p(@workflows)
      example.run
    end
  end

  before do
    stub_const("Browserctl::Recording::RECORDINGS_DIR", @recordings)
    stub_const("Browserctl::Recording::STATE_FILE",     @state_file)
    stub_const("Browserctl::BROWSERCTL_DIR",            @target)
    allow(Browserctl::Client).to receive(:new).and_return(fake_client)
    %i[navigate click fill wait url page_open].each do |m|
      allow(fake_client).to receive(m).and_return(ok: true, url: "https://example.com/done")
    end
  end

  def synthesize_5_step_recording(name)
    Browserctl::Recording.start(name)
    Browserctl::Recording.append(
      "page_open", name: "main", url: "https://example.com/login"
    )
    Browserctl::Recording.append(
      "fill", name: "main", selector: 'input[name="email"]', value: "alice@example.com",
              response: { ok: true, ref: "eaaaa", fingerprint: { text: "", role: "textbox" } }
    )
    Browserctl::Recording.append(
      "fill", name: "main", selector: 'input[name="password"]', value: "hunter2",
              response: { ok: true, ref: "ebbbb", fingerprint: { text: "", role: "textbox" } }
    )
    Browserctl::Recording.append(
      "click", name: "main", selector: "button.sign-in",
               response: { ok: true, ref: "ecccc", fingerprint: { text: "Sign in", role: "button" } }
    )
    Browserctl::Recording.append(
      "navigate", name: "main", url: "https://example.com/dashboard"
    )
    Browserctl::Recording.stop
  end

  describe "happy path: record → generate → check ×3 → promote --as-flow → invoke" do
    it "produces a globally-registered flow callable from another workflow" do
      synthesize_5_step_recording("scrape_issues")
      out = File.join(@workflows, "scrape_issues.rb")
      Browserctl::Recording.generate_workflow("scrape_issues", output_path: out, keep_log: true)
      expect(File.exist?(out)).to be(true)
      expect(File.read(out)).to include('Browserctl.workflow "scrape_issues"')
      expect(File.read(out)).to include("param :secret_password, secret: true")

      load out
      runner = Browserctl::Runner.new
      stub_const("Browserctl::Workflow::PromotionLedger::LEDGER_BASENAME",
                 File.basename(@ledger))
      allow(Browserctl::Workflow::PromotionLedger).to receive(:ledger_path).and_return(@ledger)

      verdicts = 3.times.map { runner.run_workflow("scrape_issues", check: true, secret_password: "x") }
      expect(verdicts).to all(eq(:clean))
      expect(Browserctl::Workflow::PromotionLedger.clean_streak(workflow: "scrape_issues",
                                                                path: @ledger)).to eq(3)

      result = Browserctl::Workflow::Promoter.promote(
        workflow: "scrape_issues", source_dir: @workflows,
        ledger_path: @ledger, as_flow: true, flow_dir: @flow_dir
      )

      expect(File.exist?(File.join(@target, "workflows", "scrape_issues.rb"))).to be(true)
      expect(result[:flow]).to eq(File.join(@flow_dir, "scrape_issues.rb"))
      flow_src = File.read(result[:flow])
      expect(flow_src).to include('Browserctl.flow("scrape_issues")')
      expect(flow_src).to include("param :secret_password, secret: true")

      load result[:flow]
      registered = Browserctl.flow_registry_snapshot["scrape_issues"]
      expect(registered).not_to be_nil
      expect(registered.param_defs.keys).to include(:secret_password)

      Browserctl.workflow("caller_smoke") do
        step "invoke promoted flow" do
          # The flow is invocable from any workflow because it's in the
          # global registry. We don't actually run it here — proving the
          # registration is visible across contexts is the acceptance.
          raise "flow not registered" unless Browserctl.flow_registry_snapshot["scrape_issues"]
        end
      end
      caller_verdict = runner.run_workflow("caller_smoke")
      expect(caller_verdict).to eq(:clean)
    end
  end

  describe "drift smoke: rematch is data, not failure" do
    it "returns :drift when the runner records a fingerprint rematch" do
      Browserctl.workflow("drift_smoke") do
        desc "synthetic drift via Replay::Context"
        step "interact" do
          replay_context.record(
            command: :click, selector: "form .old",
            matched_ref: "enew111", score: 0.92, reason: "rematch"
          )
        end
      end

      stub_const("Browserctl::Workflow::PromotionLedger::LEDGER_BASENAME",
                 File.basename(@ledger))
      allow(Browserctl::Workflow::PromotionLedger).to receive(:ledger_path).and_return(@ledger)

      runner = Browserctl::Runner.new
      verdict = nil
      output = capture_stdout { verdict = runner.run_workflow("drift_smoke", check: true) }

      expect(verdict).to eq(:drift)
      expect(output).to include('"drift": true')
      expect(output).to include('"rematches": 1')
      expect(Browserctl::Workflow::PromotionLedger.clean_streak(workflow: "drift_smoke",
                                                                path: @ledger)).to eq(0)

      File.write(File.join(@workflows, "drift_smoke.rb"), "# placeholder\n")
      expect do
        Browserctl::Workflow::Promoter.promote(
          workflow: "drift_smoke", source_dir: @workflows, ledger_path: @ledger
        )
      end.to raise_error(Browserctl::Workflow::Promoter::IneligibleError, /0 clean/)
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
