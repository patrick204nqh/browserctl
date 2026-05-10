# frozen_string_literal: true

require "spec_helper"
require "webrick"
require "fileutils"
require "json"
require "browserctl/state"
require "browserctl/flow"
require "browserctl/workflow"

# v0.10 acceptance: open page → load expired state → AUTH_REQUIRED →
# bound flow runs → fresh bundle saved → page reaches authenticated URL.
module StateRotateE2E
  COOKIE_NAME        = "auth"
  COOKIE_FRESH_VALUE = "valid"
  STATE_NAME         = "e2e_rotate_#{Process.pid}_#{rand(100_000)}".freeze
  FLOW_NAME          = "e2e_rotate_login_#{Process.pid}_#{rand(100_000)}".freeze
end

RSpec.describe "v0.10 state rotate end-to-end", :integration do
  include StateRotateE2E

  def start_html_server
    log    = WEBrick::Log.new(File::NULL)
    server = WEBrick::HTTPServer.new(Port: 0, Logger: log, AccessLog: [])

    # /login: drops a fresh auth cookie, returns 200.
    server.mount_proc("/login") do |_, res|
      res["Set-Cookie"] = "#{StateRotateE2E::COOKIE_NAME}=#{StateRotateE2E::COOKIE_FRESH_VALUE}; Path=/"
      res["Content-Type"] = "text/html"
      res.body = "<html><body data-test='login-ok'>logged in</body></html>"
    end

    # /dashboard: 401 without cookie, 200 with.
    server.mount_proc("/dashboard") do |req, res|
      cookie = req.cookies.find do |c|
        c.name == StateRotateE2E::COOKIE_NAME && c.value == StateRotateE2E::COOKIE_FRESH_VALUE
      end
      if cookie
        res.status = 200
        res["Content-Type"] = "text/html"
        res.body = "<html><body data-test='dashboard'>secret</body></html>"
      else
        res.status = 401
        res["Content-Type"] = "text/html"
        res.body = "<html><body data-test='unauthorized'>denied</body></html>"
      end
    end

    Thread.new { server.start }
    [server, server.config[:Port]]
  end

  def state_path(name)
    Browserctl::State.path(name)
  end

  def seed_expired_bundle(name:, flow:, host:, port:)
    payload = {
      cookies: [{
        name: StateRotateE2E::COOKIE_NAME,
        value: "expired",
        domain: host,
        path: "/",
        expires: (Time.now - 3600).to_i
      }],
      local_storage: {},
      session_storage: {}
    }
    Browserctl::State.save(
      name,
      payload: payload,
      origins: ["http://#{host}:#{port}"],
      flow: flow
    )
  end

  before(:all) do
    @client = start_daemon
    @server, @port = start_html_server

    # Register an in-process flow that satisfies the bundle's flow binding.
    # The flow logs in by hitting /login, which sets the auth cookie.
    base_url = "http://localhost:#{@port}"
    # The recovery loop calls `invoke(flow_name)` without a page argument,
    # so the FlowContext receives no page proxy. The flow drives the daemon
    # via `client` directly against the workflow's open "work" page — same
    # pattern stdlib flows will need when invoked via the auto-rotate path.
    #
    # Constants referenced by the DSL block are captured into locals first
    # because `Browserctl.flow` evaluates the block via `instance_exec`,
    # which switches the constant-lookup scope away from this file.
    flow_name = StateRotateE2E::FLOW_NAME
    Browserctl.flow(flow_name) do
      version "0.1.0"
      desc "e2e: log in by visiting /login and letting the server set a cookie"
      step "visit login" do
        client.navigate("work", "#{base_url}/login")
        client.wait("work", "[data-test=login-ok]", timeout: 5)
      end
    end
  end

  after(:all) do
    stop_daemon
    @server.shutdown
    FileUtils.rm_f(state_path(StateRotateE2E::STATE_NAME))
  end

  it "rotates an expired bundle via the bound flow and reaches the authenticated URL" do
    base_url = "http://localhost:#{@port}"

    # Pre-seed an expired bundle bound to the registered flow.
    seed_expired_bundle(name: StateRotateE2E::STATE_NAME, flow: StateRotateE2E::FLOW_NAME, host: "localhost",
                        port: @port)
    expect(File.exist?(state_path(StateRotateE2E::STATE_NAME))).to be true

    @client.page_open("work", url: "#{base_url}/")

    ctx = Browserctl::WorkflowContext.new({}, @client)

    result = ctx.load_state(StateRotateE2E::STATE_NAME)

    # Auto-rotate path fired: result carries rotated:true and the rewritten
    # bundle's load metadata (cookies count > 0).
    expect(result[:rotated]).to be(true)
    expect(result[:ok]).to be(true)

    # Now navigate to /dashboard with the rotated cookie in place — should 200.
    @client.navigate("work", "#{base_url}/dashboard")
    snap = @client.snapshot("work", format: "html")
    html = snap[:html] || snap["html"] || ""
    expect(html).to include("data-test='dashboard'").or include('data-test="dashboard"')
    expect(html).not_to include("unauthorized")
  end
end
