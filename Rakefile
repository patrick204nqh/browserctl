# frozen_string_literal: true

ASSETS_OUT = "docs/assets"

EXAMPLES = {
  "examples/the_internet/login.rb" => "#{ASSETS_OUT}/the_internet_login.png",
  "examples/the_internet/checkboxes.rb" => "#{ASSETS_OUT}/the_internet_checkboxes.png",
  "examples/the_internet/dropdown.rb" => "#{ASSETS_OUT}/the_internet_dropdown.png",
  "examples/the_internet/dynamic_loading.rb" => "#{ASSETS_OUT}/the_internet_dynamic_loading.png",
  "examples/the_internet/add_remove_elements.rb" => "#{ASSETS_OUT}/the_internet_add_remove_elements.png"
}.freeze

def shutdown_daemon
  system("bundle exec browserctl shutdown", out: File::NULL, err: File::NULL)
rescue StandardError
  nil
end

def daemon_ready?
  30.times.any? do
    break true if system("bundle exec browserctl ping", out: File::NULL, err: File::NULL)

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
        sh "bundle exec browserctl run #{example} --screenshot_path #{path}"
      end
    end
  end

  desc "Record terminal GIF with VHS  (requires: brew install vhs)"
  task :terminal do
    mkdir_p ASSETS_OUT
    sh "vhs demo/login.tape"
  end

  desc "Remove generated demo assets"
  task :clean do
    rm_f Dir["#{ASSETS_OUT}/terminal.{gif,webp}"]
    puts "Demo assets cleaned."
  end

  desc "Full pipeline: all screenshots + terminal recording"
  task all: %i[screenshots terminal]
end

desc "Run full demo pipeline  (alias for demo:all)"
task demo: "demo:all"
