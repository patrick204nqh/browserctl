# frozen_string_literal: true

require "tmpdir"
require "stringio"
require "json"
require "browserctl/recording"
require "browserctl/commands/record"

RSpec.describe Browserctl::Recording do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  before do
    stub_const("Browserctl::Recording::RECORDINGS_DIR", @tmp_dir)
    stub_const("Browserctl::Recording::STATE_FILE",     File.join(@tmp_dir, "active_recording"))
  end

  describe ".start and .active" do
    it "creates a state file with the recording name" do
      described_class.start("my_flow")
      expect(described_class.active).to eq "my_flow"
    end
  end

  describe ".stop" do
    it "removes state file and returns name" do
      described_class.start("my_flow")
      name = described_class.stop
      expect(name).to eq "my_flow"
      expect(described_class.active).to be_nil
    end

    it "raises if no active recording" do
      expect { described_class.stop }.to raise_error(/no active recording/)
    end
  end

  describe ".append" do
    it "appends a JSON line for recordable commands" do
      described_class.start("test")
      described_class.append("fill", name: "login", selector: "input", value: "hi")
      ruby = described_class.generate_workflow("test")
      expect(ruby).to include('page(:login).fill("input", params[:fill_value])')
    end

    it "ignores non-recordable commands" do
      described_class.start("test")
      described_class.append("ping")
      log = File.join(@tmp_dir, "test.jsonl")
      lines = File.readlines(log).map { |l| JSON.parse(l) }
      expect(lines.size).to eq(1) # only the _meta header
      expect(lines.first["cmd"]).to eq("_meta")
    end

    it "does nothing when no active recording" do
      described_class.append("click", name: "p", selector: "a")
      # no error, no file created
    end
  end

  describe ".append for fill commands" do
    before do
      File.write(Browserctl::Recording::STATE_FILE, "test")
    end

    it "does not record the value field for fill commands" do
      Browserctl::Recording.append(:fill, name: "main", selector: "input[name=email]", value: "secret@example.com")
      log = File.read(File.join(Browserctl::Recording::RECORDINGS_DIR, "test.jsonl"))
      expect(log).not_to include("secret@example.com")
    end

    it "still records the selector for fill commands" do
      Browserctl::Recording.append(:fill, name: "main", selector: "input[name=email]", value: "secret@example.com")
      log = File.read(File.join(Browserctl::Recording::RECORDINGS_DIR, "test.jsonl"))
      parsed = JSON.parse(log.strip)
      expect(parsed["selector"]).to eq("input[name=email]")
    end
  end

  describe ".generate_workflow" do
    it "produces valid Ruby workflow code from recorded commands" do
      described_class.start("checkout")
      described_class.append("page_open", name: "cart", url: "https://example.com/cart")
      described_class.append("click",     name: "cart", selector: "button#buy")
      described_class.stop
      ruby = described_class.generate_workflow("checkout")
      expect(ruby).to include('Browserctl.workflow "checkout"')
      expect(ruby).to include('page(:cart).navigate("https://example.com/cart")')
      expect(ruby).to include('page(:cart).click("button#buy")')
    end
  end

  describe "enriched recording log (v0.11)" do
    before { described_class.start("rich") }

    it "writes a _meta header as the first line on start" do
      log = File.readlines(File.join(@tmp_dir, "rich.jsonl"))
      meta = JSON.parse(log.first)
      expect(meta).to include(
        "cmd" => "_meta",
        "log_format" => Browserctl::Recording::LOG_FORMAT,
        "recording" => "rich"
      )
      expect(meta["started_at"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it "captures ref / fingerprint / snapshot_id / postcondition_hint from the daemon response" do
      response = {
        ok: true,
        ref: "ea1b2c3",
        fingerprint: { text: "Sign in", role: "button" },
        snapshot_id: "deadbeef00",
        postcondition_hint: { url: "https://example.com/dashboard" }
      }
      described_class.append("click", response: response, name: "main", selector: "button.sign-in")
      log = File.readlines(File.join(@tmp_dir, "rich.jsonl"))
      entry = JSON.parse(log.last)
      expect(entry).to include(
        "cmd" => "click",
        "selector" => "button.sign-in",
        "ref" => "ea1b2c3",
        "snapshot_id" => "deadbeef00"
      )
      expect(entry["fingerprint"]).to include("text" => "Sign in", "role" => "button")
      expect(entry["postcondition_hint"]).to eq({ "url" => "https://example.com/dashboard" })
    end

    it "omits replay metadata fields the response doesn't supply" do
      described_class.append("click", response: { ok: true }, name: "main", selector: "button")
      entry = JSON.parse(File.readlines(File.join(@tmp_dir, "rich.jsonl")).last)
      expect(entry).not_to have_key("ref")
      expect(entry).not_to have_key("fingerprint")
      expect(entry).not_to have_key("snapshot_id")
    end

    it "skips _meta lines when generating a workflow" do
      described_class.append("page_open", name: "cart", url: "https://example.com/cart")
      ruby = described_class.generate_workflow("rich")
      expect(ruby).not_to include("_meta")
      expect(ruby).to include('page(:cart).navigate("https://example.com/cart")')
    end
  end

  describe "workflow generate (v0.11 WS-3.2)" do
    before { described_class.start("gen") }

    it "marks fills against secret-shaped fields with secret_hint and secret_field" do
      described_class.append("fill", name: "login", selector: 'input[name="password"]', value: "hunter2")
      entry = JSON.parse(File.readlines(File.join(@tmp_dir, "gen.jsonl")).last)
      expect(entry).to include("secret_hint" => true, "secret_field" => "password")
      expect(entry).not_to have_key("value")
    end

    it "ignores non-secret fills" do
      described_class.append("fill", name: "login", selector: 'input[name="email"]', value: "a@b.c")
      entry = JSON.parse(File.readlines(File.join(@tmp_dir, "gen.jsonl")).last)
      expect(entry).not_to have_key("secret_hint")
    end

    it "emits secret_ref params and TODO header in the generated workflow" do
      described_class.append("fill", name: "login", selector: 'input[name="api_key"]', value: "k")
      described_class.append("fill", name: "login", selector: 'input[type="password"]', value: "p")
      ruby = described_class.generate_workflow("gen", keep_log: true)
      expect(ruby).to include("# TODO: review the following secret-shaped fields")
      expect(ruby).to include("#   - secret_api_key")
      expect(ruby).to include("#   - secret_password")
      expect(ruby).to include("param :secret_api_key, secret: true")
      expect(ruby).to include("page(:login).fill(\"input[name=\\\"api_key\\\"]\", params[:secret_api_key])")
      expect(ruby).to include("page(:login).fill(\"input[type=\\\"password\\\"]\", params[:secret_password])")
    end

    it "emits a fingerprint fallback comment when the recorded event has one" do
      described_class.append(
        "click",
        response: { ok: true, fingerprint: { text: "Sign in", role: "button" } },
        name: "login", selector: "button.go"
      )
      ruby = described_class.generate_workflow("gen", keep_log: true)
      expect(ruby).to match(/# fingerprint fallback: \{.*"text":"Sign in".*\}/)
      expect(ruby).to include('page(:login).click("button.go")')
    end

    it "keeps the recording log when keep_log: true" do
      described_class.append("click", name: "p", selector: "a")
      described_class.generate_workflow("gen", keep_log: true)
      expect(File.exist?(File.join(@tmp_dir, "gen.jsonl"))).to be(true)
    end

    it "deletes the log by default (record stop semantics)" do
      described_class.append("click", name: "p", selector: "a")
      described_class.generate_workflow("gen")
      expect(File.exist?(File.join(@tmp_dir, "gen.jsonl"))).to be(false)
    end
  end

  describe "secure file permissions" do
    it "creates the JSONL file with mode 0600" do
      described_class.start("secure_test")
      log_path = File.join(@tmp_dir, "secure_test.jsonl")
      mode = File.stat(log_path).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end

  describe "URL redaction" do
    before { described_class.start("redact_test") }

    it "redacts sensitive query params in navigate URLs" do
      described_class.append("navigate", name: "main", url: "https://example.com/auth?token=abc123&page=1")
      log = File.readlines(File.join(@tmp_dir, "redact_test.jsonl"))
      parsed = JSON.parse(log.last)
      expect(parsed["url"]).to include("[REDACTED]")
      expect(parsed["url"]).not_to include("abc123")
      expect(parsed["url"]).to include("page=1")
    end

    it "redacts sensitive params in page_open URLs" do
      described_class.append("page_open", name: "main", url: "https://example.com/?code=xyz&ref=home")
      log = File.readlines(File.join(@tmp_dir, "redact_test.jsonl"))
      parsed = JSON.parse(log.last)
      expect(parsed["url"]).to include("[REDACTED]")
      expect(parsed["url"]).to include("ref=home")
    end

    it "does not redact clean URLs" do
      described_class.append("navigate", name: "main", url: "https://example.com/path?page=2&sort=asc")
      log = File.readlines(File.join(@tmp_dir, "redact_test.jsonl"))
      parsed = JSON.parse(log.last)
      expect(parsed["url"]).to eq("https://example.com/path?page=2&sort=asc")
    end

    it "returns the original URL on malformed input" do
      bad_url = "not a valid url ][]["
      described_class.append("navigate", name: "main", url: bad_url)
      log = File.readlines(File.join(@tmp_dir, "redact_test.jsonl"))
      parsed = JSON.parse(log.last)
      expect(parsed["url"]).to eq(bad_url)
    end

    it "adds a comment in the generated workflow when redaction occurs" do
      described_class.append("navigate", name: "main", url: "https://example.com/?token=secret")
      ruby = described_class.generate_workflow("redact_test")
      expect(ruby).to include("# NOTE: sensitive query params were redacted during recording")
    end

    it "does not add a comment when no redaction occurs" do
      described_class.append("navigate", name: "main", url: "https://example.com/clean")
      ruby = described_class.generate_workflow("redact_test")
      expect(ruby).not_to include("# NOTE: sensitive query params were redacted")
    end
  end
end

RSpec.describe Browserctl::Commands::Record do
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  describe "record start" do
    it "emits JSON with ok and name on start" do
      allow(Browserctl::Recording).to receive(:start)
      output = capture_stdout { described_class.run(%w[start my-rec]) }
      parsed = JSON.parse(output)
      expect(parsed["ok"]).to be true
      expect(parsed["name"]).to eq("my-rec")
    end
  end

  describe "record stop" do
    it "emits JSON with ok, name, and path on stop" do
      allow(Browserctl::Recording).to receive(:stop).and_return("my-workflow")
      allow(Browserctl::Recording).to receive(:generate_workflow)
      allow(FileUtils).to receive(:mkdir_p)
      output = capture_stdout { described_class.run(["stop"]) }
      parsed = JSON.parse(output)
      expect(parsed["ok"]).to be true
      expect(parsed["name"]).to eq("my-workflow")
      expect(parsed["path"]).to include("my-workflow")
    end
  end

  describe "record status" do
    it "emits JSON with active name when recording" do
      allow(Browserctl::Recording).to receive(:active).and_return("my-rec")
      output = capture_stdout { described_class.run(["status"]) }
      parsed = JSON.parse(output)
      expect(parsed["active"]).to eq("my-rec")
    end

    it "emits JSON with null active when no recording" do
      allow(Browserctl::Recording).to receive(:active).and_return(nil)
      output = capture_stdout { described_class.run(["status"]) }
      parsed = JSON.parse(output)
      expect(parsed["active"]).to be_nil
    end
  end
end
