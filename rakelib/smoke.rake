# frozen_string_literal: true

SMOKE_FILES = %w[
  rakelib/smoke/navigation.rb
  rakelib/smoke/observation.rb
  rakelib/smoke/interaction.rb
  rakelib/smoke/upload_dialog.rb
  rakelib/smoke/cookies_storage.rb
  rakelib/smoke/session.rb
  rakelib/smoke/session_encrypted.rb
  rakelib/smoke/session_expired_if.rb
  rakelib/smoke/store_fetch.rb
  rakelib/smoke/secret_resolvers.rb
].freeze

desc "Run all smoke workflows. HEADED=1 for a visible browser."
task :smoke do
  ENV["BCTL_SMOKE_SECRET"] = "smoke-secret-ok"

  with_daemon(headed: ENV["HEADED"] == "1") do
    SMOKE_FILES.each do |file|
      puts "\n── #{file} ──"
      sh "bundle exec browserctl workflow run #{file}"
    end
  end
end
