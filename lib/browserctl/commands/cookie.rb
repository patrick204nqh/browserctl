# frozen_string_literal: true

require_relative "cli_output"
require_relative "deprecation_notice"

module Browserctl
  module Commands
    module Cookie
      extend CliOutput

      USAGE = "Usage: browserctl cookie <list|set|delete|export|import> [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        # Deprecated in v0.15 — see ADR-0021. Removed at 1.0.
        DeprecationNotice.emit(
          "cookie #{sub}",
          deprecation_replacement(sub)
        )
        case sub
        when "list"   then run_list(client, args)
        when "set"    then run_set(client, args)
        when "delete" then run_delete(client, args)
        when "export" then run_export(client, args)
        when "import" then run_import(client, args)
        else abort "unknown cookie subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.deprecation_replacement(sub)
        case sub
        when "list"   then "data list <page> --scope cookies"
        when "set"    then "data set <page> <name> <value> --scope cookies --domain DOMAIN"
        when "delete" then "data delete <page> --scope cookies"
        when "export" then "data list <page> --scope cookies  # write to file client-side"
        when "import" then "data set <page> --scope cookies"
        else "data <op> --scope cookies"
        end
      end

      def self.run_list(client, args)
        page = args.shift or abort "usage: browserctl cookie list <page>"
        print_result(client.cookies(page))
      end

      def self.run_set(client, args)
        page   = args.shift or abort "usage: browserctl cookie set <page> <name> <value> --domain DOMAIN [--path /]"
        name   = args.shift or abort "usage: browserctl cookie set <page> <name> <value> --domain DOMAIN [--path /]"
        value  = args.shift or abort "usage: browserctl cookie set <page> <name> <value> --domain DOMAIN [--path /]"
        domain_idx = args.index("--domain")
        domain = domain_idx ? args.delete_at(domain_idx + 1).tap { args.delete_at(domain_idx) } : nil
        abort "usage: browserctl cookie set <page> <name> <value> --domain DOMAIN" unless domain
        path_idx = args.index("--path")
        path = path_idx ? args.delete_at(path_idx + 1).tap { args.delete_at(path_idx) } : "/"
        print_result(client.set_cookie(page, name, value, domain, path: path))
      end

      def self.run_delete(client, args)
        page = args.shift or abort "usage: browserctl cookie delete <page>"
        print_result(client.delete_cookies(page))
      end

      def self.run_export(client, args)
        page = args.shift or abort "usage: browserctl cookie export <page> <path>"
        path = args.shift or abort "usage: browserctl cookie export <page> <path>"
        print_result(client.export_cookies(page, path))
      end

      def self.run_import(client, args)
        page = args.shift or abort "usage: browserctl cookie import <page> <path>"
        path = args.shift or abort "usage: browserctl cookie import <page> <path>"
        print_result(client.import_cookies(page, path))
      end
    end
  end
end
