# frozen_string_literal: true

require_relative "../../flow"

# HITL flow for magic-link login: pauses, asks the human to paste the
# link they received via email, then navigates the page to it.
#
# Does NOT read the email mailbox; that would require provider-specific
# IMAP/Gmail integration which belongs in a vendor flow, not stdlib.
Browserctl.flow("magic_link_email") do
  version "1.0.0"
  requires_browserctl "0.11.0"
  desc "Wait for the human to paste a magic link from their email, then navigate to it."

  param :prompt, default: "Paste the magic link from your email:"

  precondition("page proxy is present") { !page.nil? }

  step("prompt and navigate") do
    $stderr.print("[browserctl] #{prompt} ")
    link = $stdin.gets&.strip
    raise "no magic link provided" if link.nil? || link.empty?

    raise "magic link must start with http:// or https:// (got #{link.inspect})" unless link.match?(%r{\Ahttps?://}i)

    page.navigate(link)
  end
end
