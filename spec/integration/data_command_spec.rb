# frozen_string_literal: true

require "spec_helper"
require "webrick"

# Integration coverage for the unified `data` verb introduced in v0.15 by
# ADR-0021. Every combination of operation × scope that's documented as
# supported in `docs/reference/commands.md` is exercised here against a real
# browser; the surface mirrors what `cookies_spec` / `storage_spec` cover for
# the deprecated aliases.
RSpec.describe "data command (v0.15 unified verb)", :integration do
  def start_html_server
    log    = WEBrick::Log.new(File::NULL)
    server = WEBrick::HTTPServer.new(Port: 0, Logger: log, AccessLog: [])
    server.mount_proc("/") do |_, res|
      res.body = "<html><body>data test</body></html>"
      res["Content-Type"] = "text/html"
    end
    Thread.new { server.start }
    [server, server.config[:Port]]
  end

  before(:all) do
    @client = start_daemon
    @server, @port = start_html_server
    @client.page_open("data", url: "http://localhost:#{@port}/")
  end

  after(:all) do
    stop_daemon
    @server.shutdown
  end

  after do
    @client.data_delete("data", scope: "cookies")
    @client.data_delete("data", scope: "localStorage")
    @client.data_delete("data", scope: "sessionStorage")
  rescue StandardError
    nil
  end

  describe "--scope validation" do
    it "rejects an unknown scope with a typed INVALID_ARGUMENT error" do
      res = @client.data_get("data", "k", scope: "nope")
      expect(res[:error]).to match(/invalid --scope/)
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end

    it "rejects a missing scope" do
      res = @client.data_get("data", "k", scope: nil)
      expect(res[:error]).to match(/invalid --scope/)
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end
  end

  describe "scope: cookies" do
    it "set + list + delete roundtrips" do
      set = @client.data_set("data", "sid", "abc",
                             scope: "cookies", domain: ".example.com", path: "/")
      expect(set[:ok]).to be true
      expect(set[:scope]).to eq("cookies")
      expect(set[:key]).to eq("sid")

      listed = @client.data_list("data", scope: "cookies")
      expect(listed[:ok]).to be true
      expect(listed[:scope]).to eq("cookies")
      expect(listed[:count]).to be >= 1
      expect(listed[:entries].map { |c| c[:name] }).to include("sid")

      deleted = @client.data_delete("data", scope: "cookies")
      expect(deleted[:ok]).to be true
      expect(deleted[:scope]).to eq("cookies")
      expect(deleted).to have_key(:deleted)

      after = @client.data_list("data", scope: "cookies")
      expect(after[:entries]).to be_empty
    end

    it "rejects `data set` without --domain" do
      res = @client.data_set("data", "x", "y", scope: "cookies")
      expect(res[:error]).to match(/requires --domain/)
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end

    it "rejects `data get` for cookies (use data list)" do
      res = @client.data_get("data", "any", scope: "cookies")
      expect(res[:error]).to match(/not supported/)
      expect(res[:code]).to eq("INVALID_ARGUMENT")
    end
  end

  %w[localStorage sessionStorage].each do |scope|
    describe "scope: #{scope}" do
      it "set + get roundtrips" do
        set = @client.data_set("data", "theme", "dark", scope: scope)
        expect(set[:ok]).to be true
        expect(set[:scope]).to eq(scope)

        got = @client.data_get("data", "theme", scope: scope)
        expect(got[:ok]).to be true
        expect(got[:scope]).to eq(scope)
        expect(got[:key]).to eq("theme")
        expect(got[:value]).to eq("dark")
      end

      it "returns nil for an unset key" do
        res = @client.data_get("data", "missing_xyz", scope: scope)
        expect(res[:ok]).to be true
        expect(res[:value]).to be_nil
      end

      it "list returns every entry with count" do
        @client.data_set("data", "a", "1", scope: scope)
        @client.data_set("data", "b", "2", scope: scope)

        res = @client.data_list("data", scope: scope)
        expect(res[:ok]).to be true
        expect(res[:scope]).to eq(scope)
        expect(res[:count]).to be >= 2
        keys = res[:entries].map { |e| e[:key] }
        expect(keys).to include("a", "b")
      end

      it "delete clears the scope" do
        @client.data_set("data", "to_clear", "yes", scope: scope)
        res = @client.data_delete("data", scope: scope)
        expect(res[:ok]).to be true
        expect(res[:scope]).to eq(scope)
        expect(res).to have_key(:deleted)

        gone = @client.data_get("data", "to_clear", scope: scope)
        expect(gone[:value]).to be_nil
      end
    end
  end

  describe "isolation between scopes" do
    it "writing localStorage does not bleed into sessionStorage" do
      @client.data_set("data", "iso", "L", scope: "localStorage")
      @client.data_set("data", "iso", "S", scope: "sessionStorage")
      expect(@client.data_get("data", "iso", scope: "localStorage")[:value]).to eq("L")
      expect(@client.data_get("data", "iso", scope: "sessionStorage")[:value]).to eq("S")
    end
  end
end
