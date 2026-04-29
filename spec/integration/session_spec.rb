# frozen_string_literal: true

require "spec_helper"
require "webrick"
require "tmpdir"
require "json"
require "fileutils"
require "browserctl/session"

RSpec.describe "session commands", :integration do
  def start_html_server
    log    = WEBrick::Log.new(File::NULL)
    server = WEBrick::HTTPServer.new(Port: 0, Logger: log, AccessLog: [])
    server.mount_proc("/") do |_, res|
      res.body = "<html><body>session test</body></html>"
      res["Content-Type"] = "text/html"
    end
    Thread.new { server.start }
    [server, server.config[:Port]]
  end

  before(:all) do
    @client = start_daemon
    @server, @port = start_html_server
  end

  after(:all) do
    stop_daemon
    @server.shutdown
  end

  def session_dir(name)
    File.join(Browserctl::Session::BASE_DIR, name)
  end

  let(:session_name) { "test_#{Process.pid}_#{rand(100_000)}" }

  after do
    FileUtils.rm_rf(session_dir(session_name))
    begin
      @client.page_close("sp")
    rescue StandardError
      nil
    end
  end

  describe "session_save" do
    it "returns error when no pages are open" do
      res = @client.session_save(session_name)
      expect(res[:error]).to match(/no open pages/)
    end

    it "returns page and cookie counts" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.set_cookie("sp", "save_test", "cval", "localhost")

      res = @client.session_save(session_name)
      expect(res[:ok]).to be true
      expect(res[:pages]).to eq(1)
      expect(res[:cookies]).to be >= 1
    end

    it "writes metadata.json, cookies.json, and local_storage.json to disk" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.session_save(session_name)

      dir = session_dir(session_name)
      expect(File.exist?(File.join(dir, "metadata.json"))).to be true
      expect(File.exist?(File.join(dir, "cookies.json"))).to be true
      expect(File.exist?(File.join(dir, "local_storage.json"))).to be true
    end

    it "captures localStorage for the page's origin" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.storage_set("sp", "saved_key", "saved_val")
      @client.session_save(session_name)

      ls = JSON.parse(File.read(File.join(session_dir(session_name), "local_storage.json")))
      values = ls.values.first
      expect(values["saved_key"]).to eq("saved_val")
    end

    it "records the saved page's name and URL in metadata.json" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.session_save(session_name)

      meta = JSON.parse(File.read(File.join(session_dir(session_name), "metadata.json")), symbolize_names: true)
      expect(meta[:name]).to eq(session_name)
      expect(meta[:pages]).to have_key(:sp)
      expect(meta[:pages][:sp][:url]).to start_with("http://localhost:#{@port}")
    end
  end

  describe "session_list" do
    it "includes the saved session by name" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.session_save(session_name)

      res = @client.session_list
      expect(res[:ok]).to be true
      names = res[:sessions].map { |s| s[:name] }
      expect(names).to include(session_name)
    end
  end

  describe "session_delete" do
    it "removes the session directory from disk" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.session_save(session_name)
      expect(Dir.exist?(session_dir(session_name))).to be true

      @client.session_delete(session_name)
      expect(Dir.exist?(session_dir(session_name))).to be false
    end
  end

  describe "session_load" do
    it "reopens saved pages at their saved URLs" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.session_save(session_name)
      @client.page_close("sp")
      expect(@client.page_list[:pages]).not_to include("sp")

      @client.session_load(session_name)

      expect(@client.page_list[:pages]).to include("sp")
      expect(@client.url("sp")[:url]).to start_with("http://localhost:#{@port}")
    end

    it "restores cookies into the shared cookie jar" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.set_cookie("sp", "restore_me", "cookie_value", "localhost")
      @client.session_save(session_name)
      @client.delete_cookies("sp")
      expect(@client.cookies("sp")[:cookies].map { |c| c[:name] }).not_to include("restore_me")

      @client.page_close("sp")
      @client.session_load(session_name)

      cookie_names = @client.cookies("sp")[:cookies].map { |c| c[:name] }
      expect(cookie_names).to include("restore_me")
    end

    it "restores localStorage for the page's origin" do
      @client.page_open("sp", url: "http://localhost:#{@port}/")
      @client.storage_set("sp", "load_key", "load_val")
      @client.session_save(session_name)
      @client.storage_delete("sp")
      expect(@client.storage_get("sp", "load_key")[:value]).to be_nil

      @client.page_close("sp")
      @client.session_load(session_name)

      expect(@client.storage_get("sp", "load_key")[:value]).to eq("load_val")
    end

    it "returns error when the session does not exist" do
      res = @client.session_load("no_such_session_xyz_abc_123")
      expect(res[:error]).to match(/not found/)
    end
  end

  describe "load_session with expired_if:" do
    require "browserctl/runner"

    # Removes a workflow from the global registry by name.
    def deregister(*names)
      Browserctl.instance_variable_get(:@registry_mutex).synchronize do
        names.each { |n| Browserctl.instance_variable_get(:@registry).delete(n) }
      end
    end

    it "skips fallback when expired_if returns false (session is live)" do
      # Save a session that contains the auth marker in localStorage.
      @client.page_open("sess", url: "http://localhost:#{@port}/")
      @client.storage_set("sess", "auth_valid", "1")
      @client.session_save(session_name)
      @client.page_close("sess")

      fallback_ran = false
      main_wf      = "live_main_#{Process.pid}"
      fallback_wf  = "live_fallback_#{Process.pid}"

      Browserctl.workflow(fallback_wf) { step("noop") { fallback_ran = true } }
      Browserctl.workflow(main_wf) do
        step("load — session is live") do
          load_session(session_name,
                       fallback: fallback_wf,
                       expired_if: -> { page(:sess).storage_get("auth_valid") != "1" })
        end
      end

      Browserctl::Runner.new.run_workflow(main_wf)

      expect(fallback_ran).to be false
    ensure
      deregister(main_wf, fallback_wf)
      @client.page_close("sess") rescue nil
    end

    it "invokes fallback and recovers when expired_if detects a stale session" do
      # Save a session WITHOUT the auth marker — simulating a stale/logged-out save.
      @client.page_open("sess", url: "http://localhost:#{@port}/")
      @client.session_save(session_name)   # auth_valid is absent
      @client.page_close("sess")

      fallback_ran = false
      name         = session_name           # captured by fallback closure
      main_wf      = "expired_main_#{Process.pid}"
      fallback_wf  = "expired_fallback_#{Process.pid}"

      Browserctl.workflow(fallback_wf) do
        step("re-auth") do
          # Set the marker and re-save so the next session_load sees auth_valid=1.
          page(:sess).storage_set("auth_valid", "1")
          save_session(name)
          fallback_ran = true
        end
      end
      Browserctl.workflow(main_wf) do
        step("load — session is stale") do
          load_session(name,
                       fallback: fallback_wf,
                       expired_if: -> { page(:sess).storage_get("auth_valid") != "1" })
        end
      end

      Browserctl::Runner.new.run_workflow(main_wf)

      expect(fallback_ran).to be true
    ensure
      deregister(main_wf, fallback_wf)
      @client.page_close("sess") rescue nil
    end
  end
end
