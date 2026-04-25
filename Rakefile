# frozen_string_literal: true

ASSETS_OUT = "docs/assets"

EXAMPLES = {
  "examples/the_internet/login.rb"               => "#{ASSETS_OUT}/the_internet_login.png",
  "examples/the_internet/checkboxes.rb"          => "#{ASSETS_OUT}/the_internet_checkboxes.png",
  "examples/the_internet/dropdown.rb"            => "#{ASSETS_OUT}/the_internet_dropdown.png",
  "examples/the_internet/dynamic_loading.rb"     => "#{ASSETS_OUT}/the_internet_dynamic_loading.png",
  "examples/the_internet/add_remove_elements.rb" => "#{ASSETS_OUT}/the_internet_add_remove_elements.png",
}.freeze

def with_daemon(headed: false)
  system("bundle exec browserctl shutdown", out: File::NULL, err: File::NULL) rescue nil

  flags = headed ? "--headed" : ""
  pid   = spawn("bundle exec browserd #{flags}".strip)

  30.times do
    break if system("bundle exec browserctl ping", out: File::NULL, err: File::NULL)
    sleep 0.5
  end

  yield
ensure
  system("bundle exec browserctl shutdown", out: File::NULL, err: File::NULL) rescue nil
  Process.wait(pid) rescue nil
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
