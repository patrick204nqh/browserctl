# frozen_string_literal: true

require "spec_helper"
require "webrick"
require "tmpdir"
require "json"

RSpec.describe "storage commands", :integration do
  def start_html_server
    log    = WEBrick::Log.new(File::NULL)
    server = WEBrick::HTTPServer.new(Port: 0, Logger: log, AccessLog: [])
    server.mount_proc("/") do |_, res|
      res.body = "<html><body>storage test</body></html>"
      res["Content-Type"] = "text/html"
    end
    Thread.new { server.start }
    [server, server.config[:Port]]
  end

  before(:all) do
    @client = start_daemon
    @server, @port = start_html_server
    @client.page_open("store", url: "http://localhost:#{@port}/")
  end

  after(:all) do
    stop_daemon
    @server.shutdown
  end

  after do
    @client.storage_delete("store")
  rescue StandardError
    nil
  end

  describe "storage_set and storage_get" do
    it "roundtrips a localStorage key" do
      @client.storage_set("store", "theme", "dark")
      res = @client.storage_get("store", "theme")
      expect(res[:ok]).to be true
      expect(res[:value]).to eq("dark")
    end

    it "returns nil for a key that has not been set" do
      res = @client.storage_get("store", "nonexistent_xyz")
      expect(res[:ok]).to be true
      expect(res[:value]).to be_nil
    end

    it "roundtrips a sessionStorage key" do
      @client.storage_set("store", "sess_key", "sess_val", store: "session")
      res = @client.storage_get("store", "sess_key", store: "session")
      expect(res[:ok]).to be true
      expect(res[:value]).to eq("sess_val")
    end

    it "returns error for an unknown store name" do
      res = @client.storage_get("store", "k", store: "invalid_store")
      expect(res[:error]).to match(/unknown store/)
    end
  end

  describe "storage_export" do
    it "writes a JSON file containing the page's localStorage keys" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "export.json")
        @client.storage_set("store", "color", "blue")
        @client.storage_set("store", "count", "42")

        res = @client.storage_export("store", path)
        expect(res[:ok]).to be true
        expect(res[:key_count]).to be >= 2

        data = JSON.parse(File.read(path))
        expect(data).to be_a(Hash)
        values = data.values.first
        expect(values["color"]).to eq("blue")
        expect(values["count"]).to eq("42")
      end
    end

    it "returns the file path in the response" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "out.json")
        res = @client.storage_export("store", path)
        expect(res[:path]).to eq(path)
      end
    end
  end

  describe "storage_import" do
    it "seeds keys from a JSON file into the page's localStorage" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "import.json")
        File.write(path, JSON.generate({
                                         "http://localhost:#{@port}" => { "imported_key" => "imported_val", "another" => "xyz" }
                                       }))

        res = @client.storage_import("store", path)
        expect(res[:ok]).to be true
        expect(res[:key_count]).to eq(2)

        expect(@client.storage_get("store", "imported_key")[:value]).to eq("imported_val")
        expect(@client.storage_get("store", "another")[:value]).to eq("xyz")
      end
    end

    it "returns error when the file does not exist" do
      res = @client.storage_import("store", "/tmp/no_such_storage_file_xyz_abc.json")
      expect(res[:error]).to match(/file not found/)
    end
  end

  describe "storage_delete" do
    it "clears all localStorage keys" do
      @client.storage_set("store", "to_clear", "yes")
      @client.storage_set("store", "also_clear", "yes")

      @client.storage_delete("store")

      expect(@client.storage_get("store", "to_clear")[:value]).to be_nil
      expect(@client.storage_get("store", "also_clear")[:value]).to be_nil
    end

    it "clears only localStorage when stores: local is specified" do
      @client.storage_set("store", "local_key", "lv")
      @client.storage_set("store", "sess_key", "sv", store: "session")

      @client.storage_delete("store", stores: "local")

      expect(@client.storage_get("store", "local_key")[:value]).to be_nil
      expect(@client.storage_get("store", "sess_key", store: "session")[:value]).to eq("sv")
    end

    it "clears only sessionStorage when stores: session is specified" do
      @client.storage_set("store", "local_k", "lv")
      @client.storage_set("store", "sess_k", "sv", store: "session")

      @client.storage_delete("store", stores: "session")

      expect(@client.storage_get("store", "local_k")[:value]).to eq("lv")
      expect(@client.storage_get("store", "sess_k", store: "session")[:value]).to be_nil
    end
  end
end
