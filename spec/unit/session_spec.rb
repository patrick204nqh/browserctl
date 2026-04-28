# frozen_string_literal: true

require "tmpdir"
require "json"
require "browserctl/session"

RSpec.describe Browserctl::Session do
  before do
    @tmpdir = Dir.mktmpdir
    stub_const("Browserctl::Session::BASE_DIR", @tmpdir)
  end

  after { FileUtils.rm_rf(@tmpdir) }

  let(:cookies) { [{ name: "cf", value: "abc", domain: ".example.com", path: "/" }] }
  let(:local_storage) { { "https://example.com" => { "theme" => "dark" } } }
  let(:metadata) do
    { version: 1, name: "test_session", created_at: "2026-04-28T10:00:00Z",
      pages: { main: { url: "https://example.com", title: "Example" } } }
  end

  describe ".save and .load" do
    it "round-trips all session data" do
      described_class.save("test_session",
                           metadata: metadata,
                           cookies: cookies,
                           local_storage: local_storage,
                           session_storage: {})

      data = described_class.load("test_session")
      expect(data[:cookies].length).to eq(1)
      expect(data[:local_storage]["https://example.com"]["theme"]).to eq("dark")
      expect(data[:metadata][:name]).to eq("test_session")
    end

    it "omits session_storage.json when session_storage is empty" do
      described_class.save("test_session",
                           metadata: metadata, cookies: cookies,
                           local_storage: local_storage, session_storage: {})

      expect(File.exist?(File.join(described_class.path("test_session"), "session_storage.json"))).to be false
    end

    it "writes session_storage.json when non-empty" do
      described_class.save("test_session",
                           metadata: metadata, cookies: cookies,
                           local_storage: local_storage,
                           session_storage: { "https://example.com" => { "key" => "val" } })

      expect(File.exist?(File.join(described_class.path("test_session"), "session_storage.json"))).to be true
    end

    it "raises when session does not exist" do
      expect { described_class.load("missing") }.to raise_error(/not found/)
    end
  end

  describe ".all" do
    it "returns empty array when no sessions exist" do
      expect(described_class.all).to eq([])
    end

    it "returns metadata for each saved session" do
      described_class.save("s1", metadata: metadata.merge(name: "s1"), cookies: [],
                                 local_storage: {}, session_storage: {})
      described_class.save("s2", metadata: metadata.merge(name: "s2"), cookies: [],
                                 local_storage: {}, session_storage: {})
      names = described_class.all.map { |m| m[:name] }
      expect(names).to include("s1", "s2")
    end
  end

  describe ".exist? and .delete" do
    it "returns false before save and true after" do
      expect(described_class.exist?("test_session")).to be false
      described_class.save("test_session", metadata: metadata, cookies: [],
                                           local_storage: {}, session_storage: {})
      expect(described_class.exist?("test_session")).to be true
    end

    it "deletes the session directory" do
      described_class.save("test_session", metadata: metadata, cookies: [],
                                           local_storage: {}, session_storage: {})
      described_class.delete("test_session")
      expect(described_class.exist?("test_session")).to be false
    end
  end

  describe "name validation" do
    it "rejects path-traversal names" do
      expect do
        described_class.save("../../evil", metadata: metadata, cookies: [],
                                           local_storage: {}, session_storage: {})
      end
        .to raise_error(ArgumentError, /invalid session name/)
    end

    it "rejects names with slashes" do
      expect { described_class.load("foo/bar") }.to raise_error(ArgumentError, /invalid session name/)
    end

    it "accepts valid names with letters, digits, _ and -" do
      expect do
        described_class.save("my-session_01", metadata: metadata, cookies: [],
                                              local_storage: {}, session_storage: {})
      end.not_to raise_error
    end
  end

  describe "file permissions on sensitive files" do
    it "writes cookies.json with mode 0600" do
      described_class.save("test_session", metadata: metadata, cookies: cookies,
                                           local_storage: {}, session_storage: {})
      mode = File.stat(File.join(described_class.path("test_session"), "cookies.json")).mode & 0o777
      expect(mode).to eq(0o600)
    end

    it "writes local_storage.json with mode 0600" do
      described_class.save("test_session", metadata: metadata, cookies: [],
                                           local_storage: local_storage, session_storage: {})
      mode = File.stat(File.join(described_class.path("test_session"), "local_storage.json")).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end
end
