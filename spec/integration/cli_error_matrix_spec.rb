# frozen_string_literal: true

require "English"
require "json"
require "open3"
require "tmpdir"
require "fileutils"
require "spec_helper"
require "browserctl/error/codes"
require "browserctl/error/exit_codes"

# Black-box CLI integration matrix: every command × every error path that
# can be triggered without a real browser. Each cell drives the real
# `bin/browserctl` binary as a subprocess in a fresh `HOME` directory and
# asserts:
#
#   - exit status matches Browserctl::Error::ExitCodes.for(<code>)
#   - stderr contains a JSON line with "code":"<CODE>"
#
# Cells that need Chrome / a live daemon are marked `skip "needs Chrome"`
# (the existing convention in this repo's integration suite). Cells whose
# raise sites have not yet been wired in production code are marked with
# a TODO + skip — this spec is read-only test scaffolding (WS-4 / PR #19),
# and is intentionally permissive about gaps the v0.12 sweep will close.
module CliErrorMatrix
  BROWSERCTL_BIN = File.expand_path("../../bin/browserctl", __dir__)

  # exit_only: when true, assert exit code but not the JSON payload line.
  # Used for raise sites whose top-level rescue does not (yet) emit the
  # canonical structured payload — production gap noted, not fixed here.
  Cell = Struct.new(:command, :code, :scenario, :skip_reason, :exit_only, :runner, keyword_init: true)
end

RSpec.describe "CLI error code matrix" do
  # Helper: run the CLI under a tmp HOME. Returns [stdout, stderr, exit_status].
  # Each failure path here is well under 1s in practice; we rely on Open3 to
  # surface the child's exit status synchronously.
  def run_cli(args, env: {})
    Dir.mktmpdir do |home|
      base_env = { "HOME" => home, "BROWSERCTL_HOME" => home }
      out, err, status = Open3.capture3(base_env.merge(env), CliErrorMatrix::BROWSERCTL_BIN, *args)
      [out, err, status.exitstatus]
    end
  end

  # Build a .jsonl recording with a bogus format_version. `migrate` will
  # surface PROTOCOL_MISMATCH (exit 5).
  def write_bad_recording(dir, version: 999)
    path = File.join(dir, "bad.jsonl")
    File.open(path, "w") do |f|
      f.puts JSON.generate(cmd: "_meta", format_version: version, ts: Time.now.to_i)
    end
    path
  end

  # Build a workflow .rb file with a wildly-out-of-range
  # `format_version` magic comment. `migrate` will surface
  # PROTOCOL_MISMATCH for the workflow format too.
  def write_bad_workflow(dir, version: 999)
    path = File.join(dir, "bad_flow.rb")
    File.write(path, <<~RUBY)
      # frozen_string_literal: true
      # format_version: #{version}
      Browserctl.workflow "bad_flow" do
        # noop
      end
    RUBY
    path
  end

  # Build a workflow .rb file whose body trips a DSL guard at load
  # time — `step` declared without a block. `workflow run <file>`
  # `load`s the file before any params are inspected, so the typed
  # INVALID_DSL_USAGE error surfaces through the CLI's top-level
  # Browserctl::Error rescue with exit 8.
  def write_dsl_violation_workflow(dir)
    path = File.join(dir, "bad_dsl.rb")
    File.write(path, <<~RUBY)
      # frozen_string_literal: true
      # format_version: 1
      Browserctl.workflow "bad_dsl" do
        step "no-block-here"
      end
    RUBY
    path
  end

  # Each cell: [command_label, code, scenario, skip_reason_or_nil, runner_proc]
  # The runner_proc returns [out, err, status] for that scenario.
  matrix = [
    # ---------- DAEMON_UNREACHABLE (exit 4) ----------
    # Any command that goes through Browserctl::Client against an empty
    # ~/.browserctl directory raises DaemonUnavailableError, which the CLI
    # top-level rescue maps to exit 4 with code DAEMON_UNREACHABLE.
    CliErrorMatrix::Cell.new(
      command: "page list", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[page list]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "state list", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[state list]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "state load", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[state load any]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "cookie list", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[cookie list any]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "storage get", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[storage get any k]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "navigate", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[navigate any about:blank]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "url", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[url any]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "evaluate", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[evaluate any 1+1]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "fill", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[fill any #x v]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "click", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[click any #x]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "page snapshot", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[page snapshot any]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "page screenshot", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[page screenshot any]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "press", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[press any Enter]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "hover", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[hover any #x]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "select", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[select any #x v]) }
    ),
    CliErrorMatrix::Cell.new(
      command: "wait", code: "DAEMON_UNREACHABLE",
      scenario: "no daemon socket",
      runner: ->(ctx) { ctx.run_cli(%w[wait any #x --timeout 1]) }
    ),

    # ---------- PROTOCOL_MISMATCH (exit 5) ----------
    # `migrate` against an artifact whose format_version this build does
    # not know how to read raises Browserctl::ProtocolMismatch.
    # NOTE: `migrate`'s rescue writes "Error: <msg>" but not the canonical
    # JSON payload line. Exit-status contract is the part agents branch on,
    # so we pin that and leave the JSON gap for a future production tweak.
    CliErrorMatrix::Cell.new(
      command: "migrate (recording)", code: "PROTOCOL_MISMATCH",
      scenario: "recording with format_version=999",
      exit_only: true,
      runner: lambda do |ctx|
        Dir.mktmpdir do |dir|
          path = ctx.write_bad_recording(dir)
          ctx.run_cli(["migrate", path])
        end
      end
    ),
    CliErrorMatrix::Cell.new(
      command: "migrate (workflow)", code: "PROTOCOL_MISMATCH",
      scenario: "workflow with format_version=999",
      exit_only: true,
      runner: lambda do |ctx|
        Dir.mktmpdir do |dir|
          path = ctx.write_bad_workflow(dir)
          ctx.run_cli(["migrate", path])
        end
      end
    ),

    # ---------- AUTH_REQUIRED (exit 3) ----------
    # auth-check needs an open page on a live daemon to evaluate the
    # heuristics that trip AUTH_REQUIRED. No way to reach this without
    # Chrome.
    CliErrorMatrix::Cell.new(
      command: "auth-check", code: "AUTH_REQUIRED",
      scenario: "page that needs login",
      skip_reason: "needs Chrome (auth-check evaluates a live page)",
      runner: ->(_) { [+"", +"", 0] }
    ),

    # ---------- SELECTOR_NOT_FOUND (exit 6) ----------
    CliErrorMatrix::Cell.new(
      command: "click", code: "SELECTOR_NOT_FOUND",
      scenario: "selector misses on a real page",
      skip_reason: "needs Chrome (selector resolution requires a live DOM)",
      runner: ->(_) { [+"", +"", 0] }
    ),
    CliErrorMatrix::Cell.new(
      command: "fill", code: "SELECTOR_NOT_FOUND",
      scenario: "selector misses on a real page",
      skip_reason: "needs Chrome (selector resolution requires a live DOM)",
      runner: ->(_) { [+"", +"", 0] }
    ),

    # ---------- DOMAIN_NOT_ALLOWED (collapses to exit 1 / GENERIC) ----------
    CliErrorMatrix::Cell.new(
      command: "navigate", code: "DOMAIN_NOT_ALLOWED",
      scenario: "navigate blocked by allowlist",
      skip_reason: "needs Chrome + a configured domain allowlist",
      runner: ->(_) { [+"", +"", 0] }
    ),

    # ---------- KEY_NOT_FOUND (collapses to exit 1 / GENERIC) ----------
    # `cmd_fetch` raises KEY_NOT_FOUND but only via the daemon; without a
    # running browserd there's no way to exercise the typed payload from
    # the CLI surface. The CLI surface for `store/fetch` is internal-only
    # in v0.12 (no top-level command), so this cell is informational.
    CliErrorMatrix::Cell.new(
      command: "(internal) fetch", code: "KEY_NOT_FOUND",
      scenario: "unknown session key",
      skip_reason: "no CLI surface for store/fetch in v0.12 — daemon-internal RPC only",
      runner: ->(_) { [+"", +"", 0] }
    ),

    # ---------- STATE_EXPIRED (exit 7) ----------
    # No production raise site wired yet — STATE_EXPIRED is reserved in
    # the enum and exit code table but the bundle reader does not yet
    # surface a TTL check. Will land in a later v0.12 PR.
    CliErrorMatrix::Cell.new(
      command: "state load", code: "STATE_EXPIRED",
      scenario: "expired bundle",
      skip_reason: "no production raise site yet — code reserved in enum (TODO: WS-2 follow-up)",
      runner: ->(_) { [+"", +"", 0] }
    ),

    # ---------- SECRET_RESOLUTION_FAILED (collapses to exit 1) ----------
    # Reachable via `workflow run --check` against a flow that resolves a
    # missing env secret, but constructing a workflow file + runner from a
    # black-box harness is heavy. Cell is documented; not asserted.
    CliErrorMatrix::Cell.new(
      command: "workflow run --check", code: "SECRET_RESOLUTION_FAILED",
      scenario: "workflow references missing env secret",
      skip_reason: "TODO: requires a registered workflow with a secret_ref step — defer to a unit-level harness",
      runner: ->(_) { [+"", +"", 0] }
    ),

    # ---------- VALIDATION_FAILED family (exit 8) ----------
    # The codes are introduced in v0.14 WS-1 PR 1 (this PR is enum-only).
    # PRs 2/3/4 wire the raise sites in client.rb, state.rb, and the DSL
    # guards — at which point these placeholder skips will be replaced with
    # real runners. The matrix coverage spec requires every Codes::* to
    # appear at least once; these cells satisfy that without false-asserting
    # a behaviour that isn't wired yet.
    CliErrorMatrix::Cell.new(
      command: "(internal) validation", code: "VALIDATION_FAILED",
      scenario: "generic validation guard",
      skip_reason: "no production raise site yet — code reserved in enum (v0.14 WS-1 PR 2+)",
      runner: ->(_) { [+"", +"", 0] }
    ),
    CliErrorMatrix::Cell.new(
      command: "click / fill / hover / upload / select", code: "INVALID_SELECTOR_REF",
      scenario: "neither selector nor ref provided",
      skip_reason: "covered by unit spec (spec/unit/client_validation_guards_spec.rb) — " \
                   "CLI subcommands abort with usage text before reaching the Client guard",
      runner: ->(_) { [+"", +"", 0] }
    ),
    CliErrorMatrix::Cell.new(
      command: "state save / load / etc.", code: "INVALID_STATE_NAME",
      scenario: "name fails [A-Za-z0-9_-]{1,64}",
      skip_reason: "covered by unit spec — CLI state path connects to daemon before validation",
      runner: ->(_) { [+"", +"", 0] }
    ),
    CliErrorMatrix::Cell.new(
      command: "workflow run (DSL)", code: "INVALID_DSL_USAGE",
      scenario: "missing block on a step DSL call",
      runner: lambda do |ctx|
        Dir.mktmpdir do |dir|
          path = ctx.write_dsl_violation_workflow(dir)
          ctx.run_cli(["workflow", "run", path])
        end
      end
    ),
    CliErrorMatrix::Cell.new(
      command: "(internal) format_version", code: "INVALID_FORMAT_VERSION",
      scenario: "version header is not a non-negative Integer",
      skip_reason: "covered by unit spec — FormatVersion.stamp is an internal " \
                   "writer; no CLI surface accepts a user-supplied version int",
      runner: ->(_) { [+"", +"", 0] }
    ),

    # ---------- GENERIC (exit 1) ----------
    # An unknown subcommand on a known top-level group is a typed-but-
    # generic failure path. `state foo` aborts with a non-zero status that
    # collapses through the GENERIC bucket. We assert the exit status here
    # without a JSON code line — `abort` short-circuits before the typed
    # rescue, so this cell pins the *exit* surface only.
    CliErrorMatrix::Cell.new(
      command: "state <unknown>", code: "GENERIC",
      scenario: "unknown subcommand",
      runner: ->(ctx) { ctx.run_cli(%w[state nope]) }
    )
  ].freeze

  matrix.each do |cell|
    context "#{cell.command} -> #{cell.code} (#{cell.scenario})" do
      if cell.skip_reason
        it "is skipped: #{cell.skip_reason}" do
          skip cell.skip_reason
        end
        next
      end

      it "exits #{Browserctl::Error::ExitCodes.for(cell.code)} and emits {code: #{cell.code.inspect}}" do
        out, err, status = cell.runner.call(self)
        combined = "#{out}\n#{err}"

        if cell.code == "GENERIC" && cell.scenario == "unknown subcommand"
          # `abort` path — only the exit status is part of the contract.
          expect(status).to eq(Browserctl::Error::ExitCodes::GENERIC),
                            "expected GENERIC exit; got #{status}; output:\n#{combined}"
          next
        end

        expected_status = Browserctl::Error::ExitCodes.for(cell.code)
        expect(status).to eq(expected_status),
                          "expected exit #{expected_status} for #{cell.code}; got #{status}; output:\n#{combined}"

        next if cell.exit_only

        # The CLI emits two stderr lines on a typed error: a human "Error: ..."
        # line and a JSON payload. We assert the JSON line carries the right
        # canonical code so agents can branch on it deterministically.
        needle = %("code":#{cell.code.inspect})
        json_line = err.each_line.find { |ln| ln.include?(needle) }
        expect(json_line).not_to be_nil,
                                 "expected stderr to contain a JSON line with #{needle}; got:\n#{err}"

        parsed = JSON.parse(json_line)
        expect(parsed["code"]).to eq(cell.code)
      end
    end
  end

  describe "matrix coverage" do
    it "covers every canonical Codes::* at least once (reachable or skipped)" do
      represented = matrix.map(&:code).uniq
      Browserctl::Error::Codes::ALL.each do |canonical|
        expect(represented).to include(canonical),
                               "no matrix cell for canonical code #{canonical}"
      end
    end
  end
end
