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
  end

  describe "page lifecycle" do
    after do
      @client.close_page("test")
    rescue StandardError
      nil
    end

    it "opens a named page" do
      res = @client.open_page("test")
      expect(res[:ok]).to be true
      expect(res[:name]).to eq("test")
    end

    it "lists open pages" do
      @client.open_page("test")
      res = @client.list_pages
      expect(res[:pages]).to include("test")
    end

    it "closes a page" do
      @client.open_page("test")
      res = @client.close_page("test")
      expect(res[:ok]).to be true
      expect(@client.list_pages[:pages]).not_to include("test")
    end

    it "returns error for unknown page" do
      res = @client.call("goto", name: "nonexistent", url: "about:blank")
      expect(res[:error]).to match(/no page named/)
    end
  end

  describe "navigation" do
    before  { @client.open_page("nav") }
    after   do
      @client.close_page("nav")
    rescue StandardError
      nil
    end

    it "navigates and returns current url" do
      res = @client.goto("nav", "about:blank")
      expect(res[:ok]).to be true
      expect(res[:url]).to eq("about:blank")
    end

    it "reports current url" do
      @client.goto("nav", "about:blank")
      res = @client.url("nav")
      expect(res[:url]).to eq("about:blank")
    end
  end

  describe "fill and click" do
    before { @client.open_page("form") }
    after  do
      @client.close_page("form")
    rescue StandardError
      nil
    end

    it "returns error when fill selector not found" do
      @client.goto("form", "about:blank")
      res = @client.fill("form", "input#nonexistent", "value")
      expect(res[:error]).to match(/selector not found/)
    end

    it "returns error when click selector not found" do
      @client.goto("form", "about:blank")
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
      @client.goto("form", encoded)

      expect(@client.fill("form", "input#name", "hello")[:ok]).to be true
      expect(@client.click("form", "button#go")[:ok]).to be true

      clicked = @client.evaluate("form", "document.getElementById('go').dataset.clicked")
      expect(clicked[:result]).to eq("1")
    end
  end

  describe "snapshot" do
    before { @client.open_page("snap") }
    after  do
      @client.close_page("snap")
    rescue StandardError
      nil
    end

    it "returns elements snapshot as array of element hashes" do
      html = "<html><body><a href='/'>Home</a><button>Click</button></body></html>"
      encoded = "data:text/html;base64,#{[html].pack('m0')}"
      @client.goto("snap", encoded)

      res = @client.snapshot("snap", format: "elements")
      expect(res[:ok]).to be true
      expect(res[:snapshot]).to be_an(Array)
      expect(res[:snapshot].first).to include(:ref, :tag, :selector)
    end

    it "returns html snapshot" do
      @client.goto("snap", "about:blank")
      res = @client.snapshot("snap", format: "html")
      expect(res[:ok]).to be true
      expect(res[:html]).to be_a(String)
    end
  end

  describe "evaluate" do
    before { @client.open_page("eval") }
    after  do
      @client.close_page("eval")
    rescue StandardError
      nil
    end

    it "evaluates javascript and returns the result" do
      @client.goto("eval", "about:blank")
      res = @client.evaluate("eval", "1 + 2")
      expect(res[:result]).to eq(3)
    end
  end
end
