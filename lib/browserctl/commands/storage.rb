# frozen_string_literal: true

require_relative "cli_output"

module Browserctl
  module Commands
    module Storage
      extend CliOutput

      USAGE = "Usage: browserctl storage <get|set|export|import|delete> [args]"

      def self.run(client, args)
        sub = args.shift or abort USAGE
        case sub
        when "get"    then run_get(client, args)
        when "set"    then run_set(client, args)
        when "export" then run_export(client, args)
        when "import" then run_import(client, args)
        when "delete" then run_delete(client, args)
        else abort "unknown storage subcommand '#{sub}'\n#{USAGE}"
        end
      end

      def self.run_get(client, args)
        page  = args.shift or abort "usage: browserctl storage get <page> <key> [--store local|session]"
        key   = args.shift or abort "usage: browserctl storage get <page> <key> [--store local|session]"
        store = extract_opt(args, "--store") || "local"
        print_result(client.storage_get(page, key, store: store))
      end

      def self.run_set(client, args)
        page  = args.shift or abort "usage: browserctl storage set <page> <key> <value> [--store local|session]"
        key   = args.shift or abort "usage: browserctl storage set <page> <key> <value> [--store local|session]"
        value = args.shift or abort "usage: browserctl storage set <page> <key> <value> [--store local|session]"
        store = extract_opt(args, "--store") || "local"
        print_result(client.storage_set(page, key, value, store: store))
      end

      def self.run_export(client, args)
        page  = args.shift or abort "usage: browserctl storage export <page> <path> [--store local|session|all]"
        path  = args.shift or abort "usage: browserctl storage export <page> <path> [--store local|session|all]"
        store = extract_opt(args, "--store") || "all"
        print_result(client.storage_export(page, path, stores: store))
      end

      def self.run_import(client, args)
        page = args.shift or abort "usage: browserctl storage import <page> <path>"
        path = args.shift or abort "usage: browserctl storage import <page> <path>"
        print_result(client.storage_import(page, path))
      end

      def self.run_delete(client, args)
        page  = args.shift or abort "usage: browserctl storage delete <page> [--store local|session|all]"
        store = extract_opt(args, "--store") || "all"
        print_result(client.storage_delete(page, stores: store))
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
