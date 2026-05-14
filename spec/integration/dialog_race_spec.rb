# frozen_string_literal: true

require "spec_helper"
require "webrick"

# Regression test for the v0.15 WS-2 PR 4 fix. Prior to that PR,
# `dialog_accept` / `dialog_dismiss` reached into `@pages` under
# `@global_mutex` directly and skipped `with_page()`, so a concurrent
# `pause` could land between the lookup and the handler body — opening
# a race where the dialog handler would register against a page that
# had just been paused for HITL inspection.
#
# After the fix both handlers route through `with_page`, which holds
# the per-page mutex and waits on `pause_cv` while the page is paused.
# This spec proves the wait is in effect: a `dialog_accept` issued
# against a paused page must block until `resume` is called, instead
# of returning `{ ok: true }` immediately and racing.
RSpec.describe "dialog handler pause race", :integration do
  def start_html_server
    log    = WEBrick::Log.new(File::NULL)
    server = WEBrick::HTTPServer.new(Port: 0, Logger: log, AccessLog: [])
    server.mount_proc("/") do |_, res|
      res.body = <<~HTML
        <html><body>
          <button id="confirm-btn" onclick="window.confirmed=confirm('sure?')">Confirm</button>
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

  it "blocks dialog_accept while the page is paused, then completes on resume" do
    pause_res = @client.pause("p", message: "inspect")
    expect(pause_res[:paused]).to be true

    queue = Queue.new
    worker = Thread.new do
      queue << @client.dialog_accept("p")
    end

    # Give the worker enough time to reach with_page; it must NOT have
    # returned yet because the page is paused.
    sleep 0.5
    expect(worker.alive?).to be true
    expect(queue.empty?).to be true

    resume_res = @client.resume("p")
    expect(resume_res[:paused]).to be false

    result = nil
    Timeout.timeout(5) { result = queue.pop }
    worker.join(5)

    expect(result[:ok]).to be true
  end

  it "blocks dialog_dismiss while the page is paused, then completes on resume" do
    pause_res = @client.pause("p", message: "inspect")
    expect(pause_res[:paused]).to be true

    queue = Queue.new
    worker = Thread.new do
      queue << @client.dialog_dismiss("p")
    end

    sleep 0.5
    expect(worker.alive?).to be true
    expect(queue.empty?).to be true

    resume_res = @client.resume("p")
    expect(resume_res[:paused]).to be false

    result = nil
    Timeout.timeout(5) { result = queue.pop }
    worker.join(5)

    expect(result[:ok]).to be true
  end

  it "returns the no-page error when the page does not exist" do
    res = @client.dialog_accept("ghost")
    expect(res[:error]).to match(/no page named/)
  end
end
