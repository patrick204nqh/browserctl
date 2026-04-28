# frozen_string_literal: true

ASSETS_OUT = "docs/assets"

TAP_BASE = "examples/test_automation_practices"
TAP_OUT  = "test_automation_practices"

EXAMPLES = {
  "#{TAP_BASE}/auth/login.rb" => "#{ASSETS_OUT}/tap_auth_login.png",
  "#{TAP_BASE}/auth/login_negative.rb" => "#{ASSETS_OUT}/tap_auth_login_negative.png",
  "#{TAP_BASE}/dynamic/dynamic_elements.rb" => "#{ASSETS_OUT}/tap_dynamic_dynamic_elements.png",
  "#{TAP_BASE}/forms/checkboxes.rb" => "#{ASSETS_OUT}/tap_forms_checkboxes.png",
  "#{TAP_BASE}/dialogs/notifications.rb" => "#{ASSETS_OUT}/tap_dialogs_notifications.png",
  "#{TAP_BASE}/interactions/key_press.rb" => "#{ASSETS_OUT}/tap_interactions_key_press.png"
}.freeze

def shutdown_daemon
  system("bundle exec browserctl daemon stop", out: File::NULL, err: File::NULL)
rescue StandardError
  nil
end

def daemon_ready?
  30.times.any? do
    break true if system("bundle exec browserctl daemon ping", out: File::NULL, err: File::NULL)

    sleep 0.5
    false
  end
end

def with_daemon(headed: false)
  shutdown_daemon
  pid = spawn("bundle exec browserd#{' --headed' if headed}")
  abort "browserd did not start within 15 s" unless daemon_ready?
  yield
ensure
  shutdown_daemon
  Process.detach(pid) if pid
end

namespace :demo do
  desc "Capture all example screenshots (starts and stops the daemon)"
  task :screenshots do
    mkdir_p ASSETS_OUT
    with_daemon(headed: ENV["HEADED"] == "1") do
      EXAMPLES.each do |example, path|
        sh "bundle exec browserctl workflow run #{example} --screenshot_path #{path}"
      end
    end
  end

  desc "Record terminal GIF with VHS  (requires: brew install vhs gum)"
  task :terminal do
    mkdir_p ASSETS_OUT
    sh "vhs demo/login.tape"
  end

  desc "Capture browser frames and stitch into an animated GIF  (requires: ffmpeg)"
  task :browser_gif do
    frames_dir = "#{ASSETS_OUT}/.frames"
    mkdir_p frames_dir

    with_daemon(headed: ENV["HEADED"] == "1") do
      sh "bundle exec browserctl page open main --url https://moatazeldebsy.github.io/test-automation-practices/#/auth"
      sleep 2
      sh "bundle exec browserctl screenshot main --out #{frames_dir}/01_login.png"

      sh "bundle exec browserctl fill main '[data-test=username-input]' admin"
      sleep 1
      sh "bundle exec browserctl screenshot main --out #{frames_dir}/02_username.png"

      sh "bundle exec browserctl fill main '[data-test=password-input]' admin"
      sleep 1
      sh "bundle exec browserctl screenshot main --out #{frames_dir}/03_filled.png"

      sh "bundle exec browserctl click main '[data-test=login-button]'"
      sleep 3
      sh "bundle exec browserctl screenshot main --out #{frames_dir}/04_success.png"
    end

    concat = "#{frames_dir}/concat.txt"
    lines = Dir["#{frames_dir}/*.png"].map { |f| "file '#{File.expand_path(f)}'\nduration 3" }
    File.write(concat, "#{lines.join("\n")}\n")
    palette = "#{frames_dir}/palette.png"
    palettegen = "scale=1280:-1:flags=lanczos,palettegen=max_colors=256:stats_mode=full"
    sh "ffmpeg -y -f concat -safe 0 -i #{concat} -vf #{palettegen} -update 1 #{palette}"
    paletteuse = "scale=1280:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=floyd_steinberg"
    gif_out = "#{ASSETS_OUT}/browser_demo.gif"
    sh "ffmpeg -y -f concat -safe 0 -i #{concat} -i #{palette} -lavfi \"#{paletteuse}\" -loop 0 #{gif_out}"
  ensure
    rm_rf frames_dir
  end

  # ---------------------------------------------------------------------------
  # Future browser recording options — not yet implemented
  #
  # Option 1 — ffmpeg screen capture (headed browser + Xvfb in CI):
  #   Start browserd --headed, launch ffmpeg -f x11grab (Linux) or
  #   -f avfoundation (macOS) to record the browser window while CLI commands
  #   run, then convert the resulting .mp4 to GIF.
  #   Pro: continuous motion video. Con: needs Xvfb in CI, platform-specific
  #   capture flags, and window positioning to frame the browser correctly.
  #
  # Option 2 — Playwright CDP attachment + Page.startScreencast:
  #   After `browserctl open`, run `browserctl inspect <page>` to get the CDP
  #   port (@browser.process.port is already exposed via devtools.rb).
  #   Connect Playwright with connectOverCDP("ws://127.0.0.1:<port>"), send
  #   Page.startScreencast to receive JPEG frames, stitch into GIF.
  #   Pro: records only the browser viewport, no display dependency.
  #   Con: connectOverCDP doesn't support recordVideo; requires raw CDP
  #   screencast events and a frame stitcher.
  # ---------------------------------------------------------------------------

  desc "Remove generated demo assets"
  task :clean do
    rm_f "#{ASSETS_OUT}/terminal.gif"
    rm_f "#{ASSETS_OUT}/browser_demo.gif"
    puts "Demo assets cleaned."
  end

  desc "Full pipeline: all screenshots + browser GIF + terminal recording"
  task all: %i[screenshots browser_gif terminal]
end

desc "Run full demo pipeline  (alias for demo:all)"
task demo: "demo:all"
