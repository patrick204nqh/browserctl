# frozen_string_literal: true

require "spec_helper"

RSpec.describe "browserd daemon", :integration do
  before(:all) { @client = start_daemon }
  after(:all)  { stop_daemon }

  describe "ping" do
    it "responds ok with a pid" do
      res = @client.ping
      expect(res[:ok]).to be true
      expect(res[:pid]).to be_a(Integer)
    end

    it "reports protocol_version 2" do
      res = @client.ping
      expect(res[:protocol_version]).to eq("2")
    end
  end

  describe "page lifecycle" do
    after do
      @client.page_close("test")
    rescue StandardError
      nil
    end

    it "opens a named page" do
      res = @client.page_open("test")
      expect(res[:ok]).to be true
      expect(res[:name]).to eq("test")
    end

    it "lists open pages" do
      @client.page_open("test")
      res = @client.page_list
      expect(res[:pages]).to include("test")
    end

    it "closes a page" do
      @client.page_open("test")
      res = @client.page_close("test")
      expect(res[:ok]).to be true
      expect(@client.page_list[:pages]).not_to include("test")
    end

    it "returns error for unknown page" do
      res = @client.call("navigate", name: "nonexistent", url: "about:blank")
      expect(res[:error]).to match(/no page named/)
    end
  end

  describe "navigation" do
    before  { @client.page_open("nav") }
    after   do
      @client.page_close("nav")
    rescue StandardError
      nil
    end

    it "navigates and returns current url" do
      res = @client.navigate("nav", "about:blank")
      expect(res[:ok]).to be true
      expect(res[:url]).to eq("about:blank")
    end

    it "reports current url" do
      @client.navigate("nav", "about:blank")
      res = @client.url("nav")
      expect(res[:url]).to eq("about:blank")
    end
  end

  describe "fill and click" do
    before { @client.page_open("form") }
    after  do
      @client.page_close("form")
    rescue StandardError
      nil
    end

    it "returns error when fill selector not found" do
      @client.navigate("form", "about:blank")
      res = @client.fill("form", "input#nonexistent", "value")
      expect(res[:error]).to match(/selector not found/)
    end

    it "returns error when click selector not found" do
      @client.navigate("form", "about:blank")
      res = @client.click("form", "button#nonexistent")
      expect(res[:error]).to match(/selector not found/)
    end

    it "fills and clicks on a real form" do
      html = <<~HTML
        <html><body>
          <input id="name" type="text">
          <button id="go" onclick="this.dataset.clicked='1'">Go</button>
        </body></html>
      HTML
      encoded = "data:text/html;base64,#{[html].pack('m0')}"
      @client.navigate("form", encoded)

      expect(@client.fill("form", "input#name", "hello")[:ok]).to be true
      expect(@client.click("form", "button#go")[:ok]).to be true

      clicked = @client.evaluate("form", "document.getElementById('go').dataset.clicked")
      expect(clicked[:result]).to eq("1")
    end

    it "replaces existing input value rather than appending" do
      html = <<~HTML
        <html><body>
          <input id="name" type="text" value="existing">
        </body></html>
      HTML
      encoded = "data:text/html;base64,#{[html].pack('m0')}"
      @client.navigate("form", encoded)

      expect(@client.fill("form", "input#name", "replacement")[:ok]).to be true
      val = @client.evaluate("form", "document.getElementById('name').value")
      expect(val[:result]).to eq("replacement")
    end
  end

  describe "snapshot" do
    before { @client.page_open("snap") }
    after  do
      @client.page_close("snap")
    rescue StandardError
      nil
    end

    it "returns elements snapshot as array of element hashes" do
      html = "<html><body><a href='/'>Home</a><button>Click</button></body></html>"
      encoded = "data:text/html;base64,#{[html].pack('m0')}"
      @client.navigate("snap", encoded)

      res = @client.snapshot("snap", format: "elements")
      expect(res[:ok]).to be true
      expect(res[:snapshot]).to be_an(Array)
      expect(res[:snapshot].first).to include(:ref, :tag, :selector)
    end

    it "returns html snapshot" do
      @client.navigate("snap", "about:blank")
      res = @client.snapshot("snap", format: "html")
      expect(res[:ok]).to be true
      expect(res[:html]).to be_a(String)
    end
  end

  describe "evaluate" do
    before { @client.page_open("eval") }
    after  do
      @client.page_close("eval")
    rescue StandardError
      nil
    end

    it "evaluates javascript and returns the result" do
      @client.navigate("eval", "about:blank")
      res = @client.evaluate("eval", "1 + 2")
      expect(res[:result]).to eq(3)
    end
  end

  describe "page focus" do
    it "returns error in headless mode (default)" do
      res = @client.page_focus("nonexistent")
      expect(res[:error]).to match(/headed mode/)
    end

    it "returns error for missing page in headless mode" do
      res = @client.page_focus("nope")
      expect(res[:error]).not_to be_nil
    end
  end
end
