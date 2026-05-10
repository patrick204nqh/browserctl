# frozen_string_literal: true

require "tmpdir"
require "json"
require "browserctl/state"

RSpec.describe Browserctl::State do
  before do
    @tmpdir = Dir.mktmpdir
    stub_const("Browserctl::State::BASE_DIR", @tmpdir)
  end

  after { FileUtils.rm_rf(@tmpdir) }

  let(:cookies) do
    [{ name: "sess", value: "abc", domain: ".example.com", path: "/", expires: future_ts }]
  end
  let(:local_storage)   { { "https://example.com" => { "theme" => "dark" } } }
  let(:session_storage) { {} }
  def build_payload(**overrides)
    Browserctl::State::Payload.build(
      cookies: cookies,
      local_storage: local_storage,
      session_storage: session_storage,
      **overrides
    )
  end

  def future_ts = (Time.now + 86_400).to_i

  describe ".validate_name!" do
    it "accepts safe names" do
      expect { described_class.validate_name!("github_prod-1") }.not_to raise_error
    end

    it "rejects unsafe names" do
      expect { described_class.validate_name!("../oops") }.to raise_error(ArgumentError)
      expect { described_class.validate_name!("with space") }.to raise_error(ArgumentError)
    end
  end

  describe ".save / .load" do
    it "round-trips a plaintext bundle and writes to disk with 0600" do
      manifest = described_class.save("github", build_payload(flow: "github_login"))
      expect(manifest[:flow]).to eq("github_login")
      expect(manifest[:origins]).to include("https://example.com")
      expect(manifest[:expires_at]).not_to be_nil
      expect(manifest[:encrypted]).to be(false)

      file = described_class.path("github")
      expect(File.exist?(file)).to be(true)
      expect(File.stat(file).mode & 0o777).to eq(0o600)

      out = described_class.load("github")
      expect(out[:manifest][:flow]).to eq("github_login")
      expect(out[:payload]["cookies"].first["name"]).to eq("sess")
    end

    it "encrypts when a passphrase is provided and refuses to load without it" do
      described_class.save("github", build_payload(passphrase: "hunter2"))

      expect { described_class.load("github") }
        .to raise_error(Browserctl::State::Bundle::PassphraseError)

      out = described_class.load("github", passphrase: "hunter2")
      expect(out[:encrypted]).to be(true)
      expect(out[:payload]["cookies"].first["value"]).to eq("abc")
    end

    it "raises when loading a missing bundle" do
      expect { described_class.load("missing") }.to raise_error(Browserctl::Error)
    end

    it "honours an explicit --origins override" do
      manifest = described_class.save("multi",
                                      build_payload(origins: %w[https://a.test https://b.test]))
      expect(manifest[:origins]).to eq(%w[https://a.test https://b.test])
    end
  end

  describe ".info / .all" do
    before do
      described_class.save("github", build_payload(flow: "github_login"))
      described_class.save("private", build_payload(passphrase: "p"))
    end

    it "info returns manifest plus path and size, without needing passphrase" do
      info = described_class.info("private")
      expect(info[:encrypted]).to be(true)
      expect(info[:size]).to be > 0
      expect(info[:path]).to end_with("private.bctl")
    end

    it "all lists every stored bundle" do
      names = described_class.all.map { |m| m[:name] }
      expect(names).to contain_exactly("github", "private")
    end

    it "all surfaces a per-file error rather than raising on a corrupt bundle" do
      File.binwrite(described_class.path("broken"), "garbage")
      entry = described_class.all.find { |m| m[:path].end_with?("broken.bctl") }
      expect(entry[:error]).to be_a(String).and(satisfy { |s| !s.empty? })
    end
  end

  describe ".export / .import via file transport" do
    it "round-trips a bundle through a file destination" do
      described_class.save("github", build_payload(flow: "github_login"))

      Dir.mktmpdir do |tmp|
        dest = File.join(tmp, "github.bctl")
        result = described_class.export("github", dest)
        expect(result[:bytes]).to be > 0
        expect(File.exist?(dest)).to be(true)

        described_class.delete("github")
        expect(described_class.exist?("github")).to be(false)

        info = described_class.import(dest)
        expect(info[:name]).to eq("github")
        expect(described_class.exist?("github")).to be(true)
      end
    end

    it "honours --name on import" do
      described_class.save("github", build_payload)
      Dir.mktmpdir do |tmp|
        dest = File.join(tmp, "github.bctl")
        described_class.export("github", dest)
        info = described_class.import(dest, name: "renamed")
        expect(info[:name]).to eq("renamed")
        expect(described_class.exist?("renamed")).to be(true)
      end
    end

    it "rejects an import that doesn't carry the .bctl magic" do
      Dir.mktmpdir do |tmp|
        bogus = File.join(tmp, "bogus.bctl")
        File.binwrite(bogus, "not a real bundle")
        expect { described_class.import(bogus) }
          .to raise_error(Browserctl::State::Bundle::BundleError)
      end
    end

    it "raises when exporting a missing state" do
      expect { described_class.export("nope", "/tmp/x.bctl") }.to raise_error(Browserctl::Error)
    end
  end

  describe ".delete" do
    it "removes the file, no-ops when absent" do
      described_class.save("github", build_payload)
      expect(described_class.exist?("github")).to be(true)

      described_class.delete("github")
      expect(described_class.exist?("github")).to be(false)
      expect { described_class.delete("github") }.not_to raise_error
    end
  end
end
