# frozen_string_literal: true

require "spec_helper"
require "webrick"

RSpec.describe "interaction commands", :integration do
  def start_html_server
    log    = WEBrick::Log.new(File::NULL)
    server = WEBrick::HTTPServer.new(Port: 0, Logger: log, AccessLog: [])
    server.mount_proc("/") do |_, res|
      res.body = <<~HTML
        <html><body>
          <input id="name" type="text" value="hello">
          <input id="file" type="file">
          <select id="lang"><option value="ruby">Ruby</option><option value="go">Go</option></select>
          <div id="hover-target" style="width:100px;height:50px;position:absolute;top:100px;left:100px">target</div>
          <button id="alert-btn" onclick="alert('hey')">Alert</button>
          <button id="confirm-btn" onclick="window.confirmed=confirm('sure?')">Confirm</button>
          <button id="prompt-btn" onclick="window.prompted=prompt('name?')">Prompt</button>
        </body></html>
      HTML
      res["Content-Type"] = "text/html"
    end
    Thread.new { server.start }
    [server, server.config[:Port]]
  end

  before(:all) do
    @client = start_daemon
    @server, @port = start_html_server
    @client.page_open("p", url: "http://localhost:#{@port}/")
  end

  after(:all) do
    stop_daemon
    @server.shutdown
  end

  describe "press" do
    it "fires key events on the focused element" do
      res = @client.press("p", "Tab")
      expect(res[:ok]).to be true
    end

    it "returns error for missing page" do
      res = @client.press("nope", "Enter")
      expect(res[:error]).to match(/no page named/)
    end
  end

  describe "hover" do
    it "moves mouse to element without error" do
      res = @client.hover("p", "#hover-target")
      expect(res[:ok]).to be true
    end

    it "returns error when selector not found" do
      res = @client.hover("p", "#does-not-exist")
      expect(res[:error]).to match(/selector not found/)
    end
  end

  describe "upload" do
    it "returns error for a missing file" do
      res = @client.upload("p", "#file", "/tmp/nonexistent_file_xyz.txt")
      expect(res[:error]).to match(/file not found/)
    end

    it "sets the file input to an existing file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "sample.txt")
        File.write(path, "hello")
        res = @client.upload("p", "#file", path)
        expect(res[:ok]).to be true
      end
    end
  end

  describe "select" do
    it "changes the selected option" do
      res = @client.select("p", "#lang", "go")
      expect(res[:ok]).to be true
      val = @client.evaluate("p", "document.querySelector('#lang').value")
      expect(val[:result]).to eq("go")
    end

    it "returns error when selector not found" do
      res = @client.select("p", "#nope", "x")
      expect(res[:error]).to match(/selector not found/)
    end
  end

  describe "dialog accept" do
    it "accepts an alert" do
      @client.dialog_accept("p")
      @client.evaluate("p", "document.querySelector('#alert-btn').click()")
      sleep 0.3
      res = @client.evaluate("p", "1 + 1")
      expect(res[:result]).to eq(2)
    end

    it "accepts a confirm and records the result" do
      @client.dialog_accept("p")
      @client.evaluate("p", "document.querySelector('#confirm-btn').click()")
      sleep 0.3
      res = @client.evaluate("p", "window.confirmed")
      expect(res[:result]).to be true
    end

    it "passes prompt text to a prompt dialog" do
      @client.dialog_accept("p", text: "Patrick")
      @client.evaluate("p", "document.querySelector('#prompt-btn').click()")
      sleep 0.3
      res = @client.evaluate("p", "window.prompted")
      expect(res[:result]).to eq("Patrick")
    end
  end

  describe "dialog dismiss" do
    it "dismisses a confirm and records the result" do
      @client.dialog_dismiss("p")
      @client.evaluate("p", "document.querySelector('#confirm-btn').click()")
      sleep 0.3
      res = @client.evaluate("p", "window.confirmed")
      expect(res[:result]).to be false
    end
  end
end
