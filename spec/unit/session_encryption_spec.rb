# frozen_string_literal: true

require "tmpdir"
require "json"
require "browserctl/session"
require "browserctl/errors"
require "browserctl/commands/session"

RSpec.describe "Session encryption" do
  let(:cookies)         { [{ name: "auth", value: "tok123", domain: ".example.com", path: "/" }] }
  let(:local_storage)   { { "https://example.com" => { "token" => "abc" } } }
  let(:session_storage) { { "https://example.com" => { "tmp" => "1" } } }
  let(:metadata) do
    { version: 1, name: "enc_test", created_at: "2026-04-29T00:00:00Z",
      pages: { main: { url: "https://example.com", title: "Test" } } }
  end

  # --- encrypt_file / decrypt_file roundtrip ---

  describe "Browserctl::Session (private) encrypt_file / decrypt_file" do
    let(:key)       { SecureRandom.bytes(32) }
    let(:plaintext) { '{"hello":"world"}' }

    it "roundtrips arbitrary plaintext" do
      blob   = Browserctl::Session.send(:encrypt_file, plaintext, key)
      result = Browserctl::Session.send(:decrypt_file, blob, key)
      expect(result).to eq(plaintext)
    end

    it "produces a blob longer than the plaintext by nonce+tag overhead" do
      blob = Browserctl::Session.send(:encrypt_file, plaintext, key)
      # 12-byte nonce + 16-byte GCM tag = 28 bytes overhead
      expect(blob.bytesize).to eq(plaintext.bytesize + 28)
    end

    it "raises Browserctl::Error on tampered ciphertext" do
      blob = Browserctl::Session.send(:encrypt_file, plaintext, key)
      # flip a byte in the middle of the ciphertext (after nonce, before tag)
      blob.setbyte(15, blob.getbyte(15) ^ 0xFF)
      expect do
        Browserctl::Session.send(:decrypt_file, blob, key)
      end.to raise_error(Browserctl::Error, /decryption failed/)
    end

    it "raises Browserctl::Error when wrong key is used" do
      blob      = Browserctl::Session.send(:encrypt_file, plaintext, key)
      wrong_key = SecureRandom.bytes(32)
      expect do
        Browserctl::Session.send(:decrypt_file, blob, wrong_key)
      end.to raise_error(Browserctl::Error, /decryption failed/)
    end
  end

  # --- keychain_available? ---

  describe "Browserctl::Session.keychain_available?" do
    it "returns false on non-darwin platforms" do
      allow(Browserctl::Session).to receive(:keychain_available?).and_call_original
      stub_const("RUBY_PLATFORM", "x86_64-linux")
      expect(Browserctl::Session.send(:keychain_available?)).to be false
    end
  end

  # --- Session.save with encrypt: true (macOS Keychain not available) ---

  describe "Browserctl::Session.save with encrypt: true" do
    before do
      @tmpdir = Dir.mktmpdir
      stub_const("Browserctl::Session::BASE_DIR", @tmpdir)
    end

    after { FileUtils.rm_rf(@tmpdir) }

    context "when Keychain is unavailable" do
      before do
        allow(Browserctl::Session).to receive(:keychain_available?).and_return(false)
      end

      it "raises Browserctl::Error" do
        expect do
          Browserctl::Session.save("enc_test",
                                   metadata: metadata,
                                   cookies: cookies,
                                   local_storage: local_storage,
                                   session_storage: {},
                                   encrypt: true)
        end.to raise_error(Browserctl::Error, /macOS Keychain/)
      end
    end

    context "when Keychain is available (stubbed)" do
      let(:key) { SecureRandom.bytes(32) }

      before do
        allow(Browserctl::Session).to receive(:keychain_available?).and_return(true)
        allow(Browserctl::Session).to receive(:keychain_store)
        allow(SecureRandom).to receive(:bytes).and_call_original
        allow(SecureRandom).to receive(:bytes).with(32).and_return(key)
      end

      it "writes .enc files for sensitive data" do
        Browserctl::Session.save("enc_test",
                                 metadata: metadata,
                                 cookies: cookies,
                                 local_storage: local_storage,
                                 session_storage: session_storage,
                                 encrypt: true)

        dir = Browserctl::Session.path("enc_test")
        expect(File.exist?(File.join(dir, "cookies.json.enc"))).to be true
        expect(File.exist?(File.join(dir, "local_storage.json.enc"))).to be true
        expect(File.exist?(File.join(dir, "session_storage.json.enc"))).to be true
      end

      it "does not write plaintext .json for sensitive files" do
        Browserctl::Session.save("enc_test",
                                 metadata: metadata,
                                 cookies: cookies,
                                 local_storage: local_storage,
                                 session_storage: {},
                                 encrypt: true)

        dir = Browserctl::Session.path("enc_test")
        expect(File.exist?(File.join(dir, "cookies.json"))).to be false
        expect(File.exist?(File.join(dir, "local_storage.json"))).to be false
      end

      it "sets encrypted: true in metadata.json" do
        Browserctl::Session.save("enc_test",
                                 metadata: metadata,
                                 cookies: cookies,
                                 local_storage: local_storage,
                                 session_storage: {},
                                 encrypt: true)

        dir  = Browserctl::Session.path("enc_test")
        meta = JSON.parse(File.read(File.join(dir, "metadata.json")), symbolize_names: true)
        expect(meta[:encrypted]).to be true
      end

      it "stores the key in the Keychain" do
        expect(Browserctl::Session).to receive(:keychain_store).with("enc_test", key)
        Browserctl::Session.save("enc_test",
                                 metadata: metadata,
                                 cookies: cookies,
                                 local_storage: local_storage,
                                 session_storage: {},
                                 encrypt: true)
      end

      it "omits session_storage.json.enc when session_storage is empty" do
        Browserctl::Session.save("enc_test",
                                 metadata: metadata,
                                 cookies: cookies,
                                 local_storage: local_storage,
                                 session_storage: {},
                                 encrypt: true)

        dir = Browserctl::Session.path("enc_test")
        expect(File.exist?(File.join(dir, "session_storage.json.enc"))).to be false
      end
    end
  end

  # --- Session.load decrypts .enc files ---

  describe "Browserctl::Session.load with encrypted session" do
    before do
      @tmpdir = Dir.mktmpdir
      stub_const("Browserctl::Session::BASE_DIR", @tmpdir)
    end

    after { FileUtils.rm_rf(@tmpdir) }

    let(:key) { SecureRandom.bytes(32) }

    def write_encrypted_session(name, key, meta, data)
      dir = File.join(@tmpdir, name)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "metadata.json"), JSON.generate(meta))
      %i[cookies local_storage session_storage].each do |field|
        next unless data[field]

        filename = "#{field}.json.enc".sub("_", "_")
        blob = Browserctl::Session.send(:encrypt_file, JSON.generate(data[field]), key)
        File.open(File.join(dir, filename), "wb", 0o600) { |f| f.write(blob) }
      end
    end

    context "when metadata has encrypted: true" do
      before do
        enc_meta = metadata.merge(encrypted: true)
        write_encrypted_session("enc_test", key, enc_meta,
                                cookies: cookies, local_storage: local_storage, session_storage: session_storage)
        allow(Browserctl::Session).to receive(:keychain_fetch).with("enc_test").and_return(key)
      end

      it "decrypts cookies correctly" do
        data = Browserctl::Session.load("enc_test")
        expect(data[:cookies].first[:name]).to eq("auth")
        expect(data[:cookies].first[:value]).to eq("tok123")
      end

      it "decrypts local_storage correctly" do
        data = Browserctl::Session.load("enc_test")
        expect(data[:local_storage]["https://example.com"]["token"]).to eq("abc")
      end

      it "decrypts session_storage correctly" do
        data = Browserctl::Session.load("enc_test")
        expect(data[:session_storage]["https://example.com"]["tmp"]).to eq("1")
      end

      it "returns encrypted: true in metadata" do
        data = Browserctl::Session.load("enc_test")
        expect(data[:metadata][:encrypted]).to be true
      end
    end

    context "when metadata has no encrypted field (plaintext session)" do
      before do
        Browserctl::Session.save("plain_test",
                                 metadata: metadata.merge(name: "plain_test"),
                                 cookies: cookies,
                                 local_storage: local_storage,
                                 session_storage: {})
      end

      it "loads plaintext session as before" do
        data = Browserctl::Session.load("plain_test")
        expect(data[:cookies].first[:name]).to eq("auth")
        expect(data[:local_storage]["https://example.com"]["token"]).to eq("abc")
        expect(data[:metadata][:encrypted]).to be_nil
      end
    end
  end

  # --- Export encryption: derive_key ---

  describe "Browserctl::Commands::Session derive_key" do
    it "produces the same key for the same passphrase and salt" do
      salt = SecureRandom.bytes(16)
      k1   = Browserctl::Commands::Session.send(:derive_key, "hunter2", salt)
      k2   = Browserctl::Commands::Session.send(:derive_key, "hunter2", salt)
      expect(k1).to eq(k2)
    end

    it "produces a different key for a different passphrase" do
      salt = SecureRandom.bytes(16)
      k1   = Browserctl::Commands::Session.send(:derive_key, "hunter2", salt)
      k2   = Browserctl::Commands::Session.send(:derive_key, "hunter3", salt)
      expect(k1).not_to eq(k2)
    end

    it "produces a different key for a different salt" do
      k1 = Browserctl::Commands::Session.send(:derive_key, "hunter2", SecureRandom.bytes(16))
      k2 = Browserctl::Commands::Session.send(:derive_key, "hunter2", SecureRandom.bytes(16))
      expect(k1).not_to eq(k2)
    end

    it "returns a 32-byte key" do
      key = Browserctl::Commands::Session.send(:derive_key, "pass", SecureRandom.bytes(16))
      expect(key.bytesize).to eq(32)
    end
  end

  # --- Export encryption: encrypt_blob / decrypt_blob roundtrip ---

  describe "Browserctl::Commands::Session encrypt_blob / decrypt_blob" do
    let(:key)  { SecureRandom.bytes(32) }
    let(:data) { '{"cookies":[{"name":"auth","value":"tok"}]}' }

    it "roundtrips the plaintext" do
      blob   = Browserctl::Commands::Session.send(:encrypt_blob, data, key)
      result = Browserctl::Commands::Session.send(:decrypt_blob, blob, key)
      expect(result).to eq(data)
    end

    it "raises Browserctl::Error on wrong key" do
      blob = Browserctl::Commands::Session.send(:encrypt_blob, data, key)
      expect do
        Browserctl::Commands::Session.send(:decrypt_blob, blob, SecureRandom.bytes(32))
      end.to raise_error(Browserctl::Error, /export decryption failed/)
    end
  end

  # --- encrypt_export / decrypt_import full roundtrip ---

  describe "encrypted export/import roundtrip" do
    before do
      @sessions_dir = Dir.mktmpdir
      @export_dir   = Dir.mktmpdir
    end

    after do
      FileUtils.rm_rf(@sessions_dir)
      FileUtils.rm_rf(@export_dir)
    end

    def build_session_dir(name)
      dir = File.join(@sessions_dir, name)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "metadata.json"),     JSON.generate(metadata))
      File.write(File.join(dir, "cookies.json"),      JSON.generate(cookies))
      File.write(File.join(dir, "local_storage.json"), JSON.generate(local_storage))
      dir
    end

    it "encrypts and then decrypts, recovering original JSON content" do
      session_dir = build_session_dir("roundtrip")
      zip_dest    = File.join(@export_dir, "roundtrip.zip")
      passphrase  = "s3cr3tP@ss"

      Browserctl::Commands::Session.send(:encrypt_export, session_dir, "roundtrip", zip_dest, passphrase)

      # The zip must exist
      expect(File.exist?(zip_dest)).to be true

      # Decrypt into a fresh import dir
      import_dir = Dir.mktmpdir
      begin
        Browserctl::Commands::Session.send(:decrypt_import, zip_dest, import_dir, passphrase)

        restored_cookies = JSON.parse(File.read(File.join(import_dir, "roundtrip", "cookies.json")))
        expect(restored_cookies.first["name"]).to eq("auth")

        restored_ls = JSON.parse(File.read(File.join(import_dir, "roundtrip", "local_storage.json")))
        expect(restored_ls["https://example.com"]["token"]).to eq("abc")
      ensure
        FileUtils.rm_rf(import_dir)
      end
    end

    it "fails to decrypt with wrong passphrase" do
      session_dir = build_session_dir("roundtrip_fail")
      zip_dest    = File.join(@export_dir, "roundtrip_fail.zip")

      Browserctl::Commands::Session.send(:encrypt_export, session_dir, "roundtrip_fail", zip_dest, "correct")

      import_dir = Dir.mktmpdir
      begin
        expect do
          Browserctl::Commands::Session.send(:decrypt_import, zip_dest, import_dir, "wrong")
        end.to raise_error(Browserctl::Error, /export decryption failed/)
      ensure
        FileUtils.rm_rf(import_dir)
      end
    end

    it "detects encrypted zip via encrypted_zip?" do
      session_dir = build_session_dir("detect_test")
      zip_dest    = File.join(@export_dir, "detect.zip")

      Browserctl::Commands::Session.send(:encrypt_export, session_dir, "detect_test", zip_dest, "pass")

      expect(Browserctl::Commands::Session.send(:encrypted_zip?, zip_dest)).to be true
    end

    it "returns false for encrypted_zip? on a plain zip" do
      # Build a plain zip with just a text file
      plain_zip = File.join(@export_dir, "plain.zip")
      txt       = File.join(@export_dir, "hello.txt")
      File.write(txt, "hello")
      system("zip", "-j", plain_zip, txt, out: File::NULL, err: File::NULL)

      expect(Browserctl::Commands::Session.send(:encrypted_zip?, plain_zip)).to be false
    end
  end
end
