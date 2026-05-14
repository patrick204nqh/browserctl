# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    # `browserctl data <op> --scope <scope>` — unified verb for browser-side
    # persistent data. Introduced in v0.15 (ADR-0021) as the replacement for
    # the duplicated `cookie *` and `storage *` families.
    module Data
      extend CliOutput

      USAGE = "Usage: browserctl data <get|set|delete|list> --scope " \
              "{cookies|localStorage|sessionStorage} [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "get"    then run_get(client, args)
        when "set"    then run_set(client, args)
        when "delete" then run_delete(client, args)
        when "list"   then run_list(client, args)
        else abort "unknown data subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_get(client, args)
        page  = args.shift or abort "usage: browserctl data get <page> <key> --scope SCOPE"
        key   = args.shift or abort "usage: browserctl data get <page> <key> --scope SCOPE"
        scope = extract_required_scope(args)
        print_result(client.data_get(page, key, scope: scope))
      end

      SET_USAGE = "usage: browserctl data set <page> <key> <value> --scope SCOPE [--domain D] [--path /]"

      def self.run_set(client, args)
        page   = args.shift or abort SET_USAGE
        key    = args.shift or abort SET_USAGE
        value  = args.shift or abort SET_USAGE
        scope  = extract_required_scope(args)
        domain = extract_opt(args, "--domain")
        path   = extract_opt(args, "--path") || "/"
        print_result(client.data_set(page, key, value, scope: scope, domain: domain, path: path))
      end

      def self.run_delete(client, args)
        page  = args.shift or abort "usage: browserctl data delete <page> --scope SCOPE"
        scope = extract_required_scope(args)
        print_result(client.data_delete(page, scope: scope))
      end

      def self.run_list(client, args)
        page  = args.shift or abort "usage: browserctl data list <page> --scope SCOPE"
        scope = extract_required_scope(args)
        print_result(client.data_list(page, scope: scope))
      end

      def self.extract_required_scope(args)
        scope = extract_opt(args, "--scope")
        abort "missing required flag: --scope {cookies|localStorage|sessionStorage}" unless scope
        scope
      end

      def self.extract_opt(args, flag)
        idx = args.index(flag)
        return nil unless idx

        args.delete_at(idx)
        args.delete_at(idx)
      end
    end
  end
end
