# frozen_string_literal: true

# Public surface lock-file (v0.14 WS-4 PR 11, extended in v0.15 WS-3 PR 6).
#
# Locks the public surfaces documented in docs/reference/api-stability.md:
#
#   Stable zone
#   1. CLI top-level commands  — discovered by parsing the `when "<name>"`
#      lines in bin/browserctl. Top-level nouns only; subcommands of
#      `page`, `state`, `cookie`, etc. are out of scope here because they
#      live inside their own dispatcher classes under
#      lib/browserctl/commands/.
#   2. Browserctl::Client public instance methods.
#   3. Browserctl::PageProxy public instance methods (the workflow DSL
#      page object; api-stability.md refers to it as "PageProxy").
#
#   Fixed zone (v0.15 WS-3 PR 6)
#   4. Wire-protocol response shape for every command in COMMAND_MAP that
#      api-stability.md documents under "Fixed zone — command reference".
#      Each handler is invoked through a stubbed driver/page double and the
#      response keys are diffed against the lock-file `required` /
#      `optional` sets. Extras and missing-required both fail.
#
# Any drift fails the spec with a diff naming the extras (added or
# renamed in code) and the misses (removed from code). Intentional
# changes update spec/fixtures/public_surface.yml in the same PR.

require "spec_helper"
require "fileutils"
require "json"
require "tmpdir"
require "yaml"
require "browserctl/workflow"
require "browserctl/server/command_dispatcher"
require "browserctl/server/snapshot_builder"
require "browserctl/server/page_session"

# Test-harness context helper for the Fixed-zone wire-protocol response-shape
# lock. Defined at the top level (not inside the describe block) so RuboCop's
# Lint/ConstantDefinitionInBlock is happy. Wraps an RSpec example group so
# harness lambdas can call `instance_double`, `double`, and `allow` directly.
PublicSurfaceFixedZoneContext = Struct.new(:driver, :pages, :test) do
  def allow(*args, &block) = test.allow(*args, &block)
  def instance_double(*args, **kwargs) = test.instance_double(*args, **kwargs)
  def double(*args, **kwargs) = test.double(*args, **kwargs)
end

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

  describe "Fixed-zone wire-protocol response shapes" do
    # Per-command harness: stubs the minimum driver/page surface each
    # handler touches and invokes the handler through the dispatcher.
    # The block returns the request hash; the surrounding test asserts the
    # response keys match the lock-file's required/optional sets.
    harnesses = {
      "page_open" => lambda do |ctx|
        page = instance_double("Ferrum::Page", go_to: nil)
        allow(ctx.driver).to receive(:create_page).and_return(page)
        { cmd: "page_open", name: "main" }
      end,
      "page_close" => lambda do |ctx|
        page = instance_double("Ferrum::Page", close: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "page_close", name: "main" }
      end,
      "page_list" => lambda do |_ctx|
        { cmd: "page_list" }
      end,
      "page_focus" => lambda do |ctx|
        page = instance_double("Ferrum::Page", activate: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        allow(ctx.driver).to receive(:headed?).and_return(true)
        { cmd: "page_focus", name: "main" }
      end,
      "navigate" => lambda do |ctx|
        page = instance_double("Ferrum::Page",
                               go_to: nil,
                               current_url: "https://example.com",
                               body: "<html></html>")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "navigate", name: "main", url: "https://example.com" }
      end,
      "fill" => lambda do |ctx|
        el   = double("el", focus: nil, evaluate: nil, type: nil)
        page = instance_double("Ferrum::Page",
                               at_css: el,
                               current_url: "https://example.com")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "fill", name: "main", selector: "input", value: "x" }
      end,
      "click" => lambda do |ctx|
        el   = double("el", evaluate: nil)
        page = instance_double("Ferrum::Page",
                               at_css: el,
                               current_url: "https://example.com")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "click", name: "main", selector: "button" }
      end,
      "evaluate" => lambda do |ctx|
        page = instance_double("Ferrum::Page", evaluate: 42)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "evaluate", name: "main", expression: "1 + 1" }
      end,
      "url" => lambda do |ctx|
        page = instance_double("Ferrum::Page", current_url: "https://example.com")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "url", name: "main" }
      end,
      "wait" => lambda do |ctx|
        page = instance_double("Ferrum::Page", at_css: double("el"))
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "wait", name: "main", selector: ".ready", timeout: 1 }
      end,
      "snapshot" => lambda do |ctx|
        page = instance_double("Ferrum::Page",
                               body: "<html><body><button>Go</button></body></html>",
                               current_url: "https://example.com")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "snapshot", name: "main", format: "elements" }
      end,
      "screenshot" => lambda do |ctx|
        path = File.expand_path("~/.browserctl/screenshots/lock_test.png")
        FileUtils.mkdir_p(File.dirname(path))
        page = instance_double("Ferrum::Page", screenshot: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "screenshot", name: "main", path: path }
      end,
      "pause" => lambda do |ctx|
        page = instance_double("Ferrum::Page")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "pause", name: "main" }
      end,
      "resume" => lambda do |ctx|
        page = instance_double("Ferrum::Page")
        session = Browserctl::PageSession.new(page)
        session.pause!
        ctx.pages["main"] = session
        { cmd: "resume", name: "main" }
      end,
      "cookies" => lambda do |ctx|
        cookies = double("cookies", all: {})
        page    = instance_double("Ferrum::Page", cookies: cookies)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "cookies", name: "main" }
      end,
      "set_cookie" => lambda do |ctx|
        cookies = double("cookies")
        allow(cookies).to receive(:set)
        page = instance_double("Ferrum::Page", cookies: cookies)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "set_cookie", name: "main", cookie_name: "c", value: "v", domain: "example.com" }
      end,
      "delete_cookies" => lambda do |ctx|
        cookies = double("cookies", clear: nil)
        page    = instance_double("Ferrum::Page", cookies: cookies)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "delete_cookies", name: "main" }
      end,
      "import_cookies" => lambda do |ctx|
        cookies = double("cookies")
        allow(cookies).to receive(:set)
        page = instance_double("Ferrum::Page", cookies: cookies)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "import_cookies", name: "main",
          cookies: [{ name: "c", value: "v", domain: "example.com" }] }
      end,
      "storage_get" => lambda do |ctx|
        page = instance_double("Ferrum::Page", evaluate: "stored")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "storage_get", name: "main", key: "k" }
      end,
      "storage_set" => lambda do |ctx|
        page = instance_double("Ferrum::Page", evaluate: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "storage_set", name: "main", key: "k", value: "v" }
      end,
      "storage_export" => lambda do |ctx|
        page = instance_double("Ferrum::Page")
        allow(page).to receive(:evaluate).and_return("https://example.com", "{}", "{}")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        path = File.join(Dir.mktmpdir("storage-export"), "out.json")
        { cmd: "storage_export", name: "main", path: path }
      end,
      "storage_import" => lambda do |ctx|
        page = instance_double("Ferrum::Page", evaluate: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        path = File.join(Dir.mktmpdir("storage-import"), "in.json")
        File.write(path, JSON.generate({ "https://example.com" => { "k" => "v" } }))
        { cmd: "storage_import", name: "main", path: path }
      end,
      "storage_delete" => lambda do |ctx|
        page = instance_double("Ferrum::Page", evaluate: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "storage_delete", name: "main" }
      end,
      "devtools" => lambda do |ctx|
        page = instance_double("Ferrum::Page")
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        allow(ctx.driver).to receive(:supports?).with(:devtools).and_return(true)
        info = { port: 9222, target_id: "ABC" }
        allow(ctx.driver).to receive(:devtools_info)
        .with(an_instance_of(Browserctl::Driver::FerrumPageDriver)).and_return(info)
        { cmd: "devtools", name: "main" }
      end,
      "ping" => lambda do |_ctx|
        { cmd: "ping" }
      end,
      "shutdown" => lambda do |_ctx|
        allow(Process).to receive(:kill).with("INT", Process.pid)
        { cmd: "shutdown" }
      end,
      "press" => lambda do |ctx|
        keyboard = double("keyboard", down: nil, up: nil)
        page = instance_double("Ferrum::Page", keyboard: keyboard)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "press", name: "main", key: "Enter" }
      end,
      "hover" => lambda do |ctx|
        mouse = double("mouse", move: nil)
        page  = instance_double("Ferrum::Page",
                                evaluate: { "x" => 1.0, "y" => 1.0 },
                                mouse: mouse)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "hover", name: "main", selector: "button" }
      end,
      "upload" => lambda do |ctx|
        path = File.join(Dir.mktmpdir("upload"), "f.txt")
        File.write(path, "x")
        el   = double("el", select_file: nil)
        page = instance_double("Ferrum::Page", at_css: el)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "upload", name: "main", selector: "input[type=file]", path: path }
      end,
      "select" => lambda do |ctx|
        el   = double("el", evaluate: nil)
        page = instance_double("Ferrum::Page", at_css: el)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "select", name: "main", selector: "select", value: "opt1" }
      end,
      "dialog_accept" => lambda do |ctx|
        page = instance_double("Ferrum::Page", on: "sub-1", off: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "dialog_accept", name: "main" }
      end,
      "dialog_dismiss" => lambda do |ctx|
        page = instance_double("Ferrum::Page", on: "sub-1", off: nil)
        ctx.pages["main"] = Browserctl::PageSession.new(page)
        { cmd: "dialog_dismiss", name: "main" }
      end
    }.freeze

    let(:fixed_zone) { expected.fetch("fixed_zone") }

    it "covers every command in COMMAND_MAP that api-stability.md lists as Fixed" do
      # auth_check, store, fetch, state_* are intentionally excluded:
      # auth_check / state_* aren't yet promoted to the Fixed-zone command
      # reference; store / fetch are explicitly Extension.
      extension_or_unlisted = %w[auth_check store fetch
                                 state_save state_load state_list state_info state_delete]
      command_map_keys = Browserctl::CommandDispatcher::COMMAND_MAP.keys - extension_or_unlisted
      expect(command_map_keys.sort).to eq(fixed_zone.keys.sort),
                                       "COMMAND_MAP and fixed_zone: are out of sync — update " \
                                       "spec/fixtures/public_surface.yml or COMMAND_MAP."
    end

    harnesses.each_key do |command|
      it "#{command}: response shape matches the lock-file" do
        spec   = harnesses.fetch(command)
        shape  = expected.fetch("fixed_zone").fetch(command)
        req    = shape.fetch("required").map(&:to_sym)
        opt    = shape.fetch("optional").map(&:to_sym)
        allowed = (req + opt).to_set

        driver = double("driver")
        pages  = {}
        ctx    = PublicSurfaceFixedZoneContext.new(driver, pages, self)
        request = instance_exec(ctx, &spec)

        builder    = Browserctl::SnapshotBuilder.new
        dispatcher = Browserctl::CommandDispatcher.new(pages, driver, builder)
        response   = dispatcher.dispatch(request)

        expect(response).not_to have_key(:error),
                                "expected success for #{command}, got error: #{response[:error].inspect}"

        actual_keys = response.keys.to_set
        missing     = req - actual_keys.to_a
        extras      = actual_keys.to_a - allowed.to_a

        expect(missing).to be_empty,
                           "#{command}: missing required keys #{missing.inspect}. " \
                           "If this is intentional, update spec/fixtures/public_surface.yml."
        expect(extras).to be_empty,
                          "#{command}: response contains keys not in the lock-file #{extras.inspect}. " \
                          "If this is intentional, add them to spec/fixtures/public_surface.yml " \
                          "under fixed_zone.#{command}.optional (or required)."
      end
    end
  end
end
