# frozen_string_literal: true

require_relative "lib/browserctl/version"

Gem::Specification.new do |s| # rubocop:disable Metrics/BlockLength
  s.name        = "browserctl"
  s.version     = Browserctl::VERSION
  s.summary     = "Persistent browser automation daemon and CLI for AI agents and developer workflows"
  s.description = "Named browser sessions, Ruby workflow DSL, and a token-efficient DOM snapshot format. " \
                  "Built on Ferrum (Chrome DevTools Protocol)."
  s.authors     = ["Patrick"]
  s.email       = ["patrick204nqh@gmail.com"]
  s.homepage    = "https://github.com/patrick204nqh/browserctl"
  s.license     = "MIT"

  s.metadata = {
    "homepage_uri" => s.homepage,
    "source_code_uri" => s.homepage,
    "changelog_uri" => "#{s.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{s.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  s.required_ruby_version = ">= 3.3"

  s.files         = Dir["lib/**/*.rb", "bin/*", "examples/**/*.rb"] +
                    %w[README.md CHANGELOG.md LICENSE]
  s.executables   = %w[browserd browserctl]
  s.require_paths = ["lib"]

  s.add_dependency "ferrum",   "~> 0.15"
  s.add_dependency "nokogiri", "~> 1.16"
  s.add_dependency "optimist", "~> 3.1"

  s.add_development_dependency "lefthook", "~> 2.1"
  s.add_development_dependency "rake",     "~> 13.0"
  s.add_development_dependency "rspec",    "~> 3.13"
  s.add_development_dependency "rubocop",  "~> 1.65"
  s.add_development_dependency "yard",     "~> 0.9"
end
