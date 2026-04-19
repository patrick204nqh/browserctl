require_relative "lib/browserctl/version"

Gem::Specification.new do |s|
  s.name        = "browserctl"
  s.version     = Browserctl::VERSION
  s.summary     = "Persistent browser automation daemon + CLI for AI agents"
  s.description = "A Ferrum-backed browser server with a discrete command CLI and a Ruby workflow DSL, designed for AI agent use."
  s.authors     = ["Patrick"]
  s.email       = ["patrick204nqh@gmail.com"]
  s.homepage    = "https://github.com/patrick204nqh/browserctl"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.2"

  s.files         = Dir["lib/**/*.rb", "bin/*", "skills/**/*", "workflows/**/*.rb"]
  s.executables   = %w[browserd browserctl]
  s.require_paths = ["lib"]

  s.add_dependency "ferrum",   "~> 0.15"
  s.add_dependency "optimist", "~> 3.1"
  s.add_dependency "nokogiri", "~> 1.16"

  s.add_development_dependency "rspec",   "~> 3.13"
  s.add_development_dependency "rubocop", "~> 1.65"
end
