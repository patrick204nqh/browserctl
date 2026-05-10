# frozen_string_literal: true

require "fileutils"
require "json"
require "time"
require_relative "constants"
require_relative "errors"
require_relative "version"
require_relative "state/bundle"
require_relative "state/transport"
require_relative "state/transports/file"
require_relative "state/transports/s3"
require_relative "state/transports/one_password"

module Browserctl
  # Top-level state store: a single .bctl bundle per name under
  # ~/.browserctl/state/<name>.bctl. Wraps the Bundle codec with on-disk
  # naming, validation, and a small inventory API used by `state list/info`.
  #
  # Data shape inside a bundle:
  #
  #   manifest = {
  #     name:        String,
  #     version:     1,                       # bundle schema version
  #     producer:    "browserctl/<gem-ver>",
  #     created_at:  ISO-8601,
  #     origins:     [String, ...],
  #     flow:        String | nil,            # bound flow name, for `state rotate`
  #     flow_version: String | nil,
  #     expires_at:  ISO-8601 | nil,          # earliest cookie expiry
  #     encrypted:   Boolean
  #   }
  #
  #   payload = {
  #     cookies:         [Hash, ...],
  #     local_storage:   { origin => { key => value } },
  #     session_storage: { origin => { key => value } }
  #   }
  module State
    BASE_DIR  = File.join(BROWSERCTL_DIR, "state")
    SAFE_NAME = /\A[a-zA-Z0-9_-]{1,64}\z/
    EXTENSION = ".bctl"
    MANIFEST_VERSION = 1

    # Value object bundling everything needed to persist a state bundle. The
    # browser-side data lives in `cookies`, `local_storage`, and
    # `session_storage`; the manifest extras live in `origins`, `flow`, and
    # `flow_version`; `passphrase` flips the bundle into an encrypted variant.
    Payload = Data.define(
      :cookies,
      :local_storage,
      :session_storage,
      :origins,
      :flow,
      :flow_version,
      :passphrase
    ) do
      def self.build(cookies: [], local_storage: {}, session_storage: {}, # rubocop:disable Metrics/ParameterLists
                     origins: nil, flow: nil, flow_version: nil, passphrase: nil)
        new(
          cookies: cookies,
          local_storage: local_storage,
          session_storage: session_storage,
          origins: origins,
          flow: flow,
          flow_version: flow_version,
          passphrase: passphrase
        )
      end

      def to_bundle_payload
        {
          cookies: cookies,
          local_storage: local_storage,
          session_storage: session_storage
        }
      end
    end

    def self.path(name) = File.join(BASE_DIR, "#{name}#{EXTENSION}")
    def self.exist?(name) = File.exist?(path(name))

    def self.validate_name!(name)
      return if SAFE_NAME.match?(name.to_s)

      raise ArgumentError, "invalid state name #{name.inspect} — use letters, digits, _ or - (max 64 chars)"
    end

    # Persist a bundle. `payload` is a `State::Payload` value object carrying
    # cookies, local/session storage, and the manifest extras (origins, flow,
    # flow_version, passphrase).
    def self.save(name, payload)
      validate_name!(name)
      FileUtils.mkdir_p(BASE_DIR)

      bundle_payload = payload.to_bundle_payload
      manifest = build_manifest(
        name: name,
        origins: payload.origins || derive_origins(bundle_payload),
        flow: payload.flow,
        flow_version: payload.flow_version,
        cookies: payload.cookies || [],
        encrypted: !payload.passphrase.nil?
      )

      blob = Bundle.encode(manifest: manifest, payload: bundle_payload, passphrase: payload.passphrase)
      File.open(path(name), "wb", 0o600) { |f| f.write(blob) }
      manifest
    end

    # Load and decode a bundle. Returns { manifest:, payload:, encrypted: }.
    def self.load(name, passphrase: nil)
      validate_name!(name)
      raise Browserctl::Error, "state '#{name}' not found" unless exist?(name)

      Bundle.decode(File.binread(path(name)), passphrase: passphrase)
    end

    def self.delete(name)
      validate_name!(name)
      FileUtils.rm_f(path(name))
    end

    # Copies the on-disk .bctl bundle to a transport-addressable destination
    # (file path, s3://bucket/key, op://Vault/Item, or any registered scheme).
    # Bundle bytes are written verbatim — no re-encoding — so the receiving
    # side can verify the manifest/payload exactly as produced.
    def self.export(name, destination)
      validate_name!(name)
      raise Browserctl::Error, "state '#{name}' not found" unless exist?(name)

      transport, parsed = Transport.for(destination)
      blob = ::File.binread(path(name))
      transport.write(parsed, blob)
      { name: name, destination: destination, bytes: blob.bytesize }
    end

    # Pulls a bundle from a transport-addressable source and stores it as a
    # local state. Validates the magic header before persisting so we never
    # leave a corrupt bundle in the state directory. `name` defaults to the
    # source's basename without `.bctl`.
    def self.import(source, name: nil)
      transport, parsed = Transport.for(source)
      blob = transport.read(parsed)
      raise Bundle::BundleError, "imported blob is not a .bctl bundle" unless blob.start_with?(Bundle::MAGIC)

      manifest = Bundle.peek_manifest(blob)
      target_name = name || derive_name(source) || manifest[:name]
      validate_name!(target_name)

      FileUtils.mkdir_p(BASE_DIR)
      ::File.open(path(target_name), "wb", 0o600) { |f| f.write(blob) }
      { name: target_name, source: source, bytes: blob.bytesize, encrypted: manifest[:encrypted] }
    end

    def self.derive_name(uri)
      base = ::File.basename(uri.to_s.split("?").first.to_s, EXTENSION)
      return nil if base.empty?

      base
    end
    private_class_method :derive_name

    # Read manifests for all stored bundles. Errors on a single file are
    # surfaced via { error: "...", path: "..." } rather than aborting the list.
    def self.all
      return [] unless Dir.exist?(BASE_DIR)

      Dir[File.join(BASE_DIR, "*#{EXTENSION}")].map do |file|
        info_for(file)
      end
    end

    # Inspect a single bundle without decrypting the payload.
    def self.info(name)
      validate_name!(name)
      raise Browserctl::Error, "state '#{name}' not found" unless exist?(name)

      info_for(path(name))
    end

    def self.info_for(file)
      blob     = File.binread(file)
      manifest = Bundle.peek_manifest(blob)
      manifest.merge(
        path: file,
        size: blob.bytesize
      )
    rescue Bundle::BundleError => e
      { name: File.basename(file, EXTENSION), path: file, error: e.message }
    end
    private_class_method :info_for

    def self.build_manifest(name:, origins:, flow:, flow_version:, cookies:, encrypted:) # rubocop:disable Metrics/ParameterLists
      {
        name: name,
        version: MANIFEST_VERSION,
        producer: "browserctl/#{Browserctl::VERSION}",
        created_at: Time.now.utc.iso8601,
        origins: Array(origins).compact.uniq,
        flow: flow,
        flow_version: flow_version,
        expires_at: earliest_expiry(cookies),
        encrypted: encrypted
      }
    end
    private_class_method :build_manifest

    # Origins captured from the payload itself when not overridden. Pulls from
    # cookie domains and storage keys to cover both navigation-tracked and
    # cookie-only auth.
    def self.derive_origins(payload)
      cookies = fetch_either(payload, :cookies, "cookies", default: [])
      ls      = fetch_either(payload, :local_storage, "local_storage", default: {})
      ss      = fetch_either(payload, :session_storage, "session_storage", default: {})

      (origins_from_cookies(cookies) + ls.keys.map(&:to_s) + ss.keys.map(&:to_s)).uniq
    end
    private_class_method :derive_origins

    def self.origins_from_cookies(cookies)
      cookies.filter_map do |c|
        domain = (c[:domain] || c["domain"]).to_s
        next if domain.empty?

        domain.start_with?(".") ? "https://#{domain[1..]}" : "https://#{domain}"
      end
    end
    private_class_method :origins_from_cookies

    def self.fetch_either(hash, sym_key, str_key, default:)
      hash[sym_key] || hash[str_key] || default
    end
    private_class_method :fetch_either

    def self.earliest_expiry(cookies)
      times = cookies.filter_map do |c|
        v = c[:expires] || c["expires"] || c[:expiresAt] || c["expiresAt"]
        v&.to_f&.positive? ? Time.at(v.to_f).utc.iso8601 : nil
      end
      times.min
    end
    private_class_method :earliest_expiry
  end
end
