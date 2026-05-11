# frozen_string_literal: true

require "io/console"

module Browserctl
  module Commands
    # Stdin/stderr passphrase prompting for `browserctl state` commands.
    # Honours `BROWSERCTL_STATE_PASSPHRASE` for non-interactive use; otherwise
    # reads from a tty with echo disabled and optional confirmation.
    module PassphrasePrompt
      module_function

      # @return [String]
      def read(confirm: false)
        return ENV["BROWSERCTL_STATE_PASSPHRASE"] if ENV["BROWSERCTL_STATE_PASSPHRASE"]

        pass = ask("Passphrase: ")
        if confirm
          confirm_pass = ask("Confirm passphrase: ")
          abort "Passphrases do not match." unless pass == confirm_pass
        end
        pass
      end

      # Peek at the manifest first so we only prompt when the bundle is
      # actually encrypted.
      def needed_for?(client, name)
        info = client.state_info(name)
        return false if info[:error] || info["error"]

        manifest = info[:info] || info["info"] || {}
        manifest[:encrypted] || manifest["encrypted"] || false
      end

      def ask(label)
        $stderr.print(label)
        value = $stdin.noecho(&:gets).to_s.chomp
        $stderr.puts
        value
      end
      private_class_method :ask
    end
  end
end
