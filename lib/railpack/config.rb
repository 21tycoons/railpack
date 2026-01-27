require "yaml"

module Railpack
  # Configuration handler for Railpack bundling settings.
  #
  # This class provides immutable, environment-aware configuration management with:
  # - YAML-based config loading from config/railpack.yml
  # - Three-level merge order: defaults → bundler-specific → environment-specific
  # - Deep-frozen configs for immutability and thread safety
  # - Explicit accessors for common config keys with method_missing fallback
  #
  # Example config/railpack.yml:
  #   default:
  #     bundler: bun
  #     outdir: app/assets/builds
  #   development:
  #     sourcemap: true
  #   production:
  #     minify: true
  #
  # All configs are immutable after loading. Set values in config/railpack.yml only.
  class Config
    class Error < StandardError; end

    # Known config keys that get explicit accessors
    CONFIG_KEYS = %w[
      target format minify sourcemap splitting
      entrypoint entrypoints outdir platform mode analyze_bundle
    ].freeze

    attr_reader :config

    def initialize
      @config = load_config
      @merged_cache = {}
    end

    def current_env
      if defined?(Rails) && Rails.respond_to?(:env)
        Rails.env
      else
        :development
      end
    end

    # Explicit accessors for known config keys
    CONFIG_KEYS.each do |key|
      define_method(key) do |env = current_env|
        for_environment(env)[key]
      end
    end

    def for_environment(env = current_env)
      @merged_cache[env.to_s] ||= begin
        base_config = @config["default"] || {}
        bundler_config = bundler_config(env)
        env_config = @config[env.to_s] || {}

        # Merge: default <- bundler <- environment
        merged = deep_merge(deep_merge(base_config, bundler_config), env_config)

        # Validate critical config values
        validate_config!(merged, env)

        # Deep freeze for immutability
        deep_freeze(merged)
      end
    end

    # Reload configuration (useful for development/testing)
    def reload!
      @config = load_config
      @merged_cache.clear
      self
    end

    def bundler(env = current_env)
      # Look directly in config to avoid circular dependency
      env_config = @config[env.to_s] || {}
      default_config = @config["default"] || {}
      env_config['bundler'] || default_config['bundler'] || 'bun'
    end

    def bundler_config(env = current_env)
      bundler_name = bundler(env)
      @config[bundler_name] || {}
    end

    def method_missing(method, *args)
      config_key = method.to_s
      if method.end_with?('=')
        # Setter - no longer allowed, config is immutable
        raise Error, "Config is immutable. Set values in config/railpack.yml"
      else
        # Getter - read from merged config (backward compatibility)
        # TODO: In v2.0, remove this fallback and require explicit accessors
        warn "DEPRECATED: Dynamic config access via '#{config_key}' will be removed in v2.0. Use explicit accessors instead." if defined?(Rails) && Rails.logger
        env = args.first || current_env
        return for_environment(env)[config_key] if for_environment(env).key?(config_key)
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      config_key = method.to_s.chomp('=')
      env = current_env
      for_environment(env).key?(config_key) || super
    end

    # Build command flags from config
    def build_flags(env = current_env)
      cfg = for_environment(env)
      flags = []

      flags << "--target=#{cfg['target']}" if cfg['target']
      flags << "--format=#{cfg['format']}" if cfg['format']
      flags << "--minify" if cfg['minify']
      flags << "--sourcemap" if cfg['sourcemap']
      flags << "--splitting" if cfg['splitting']

      flags
    end

    # Build command arguments
    def build_args(env = current_env)
      cfg = for_environment(env)
      args = []

      # Support multiple entrypoints or single entrypoint
      entrypoints = cfg['entrypoints']
      if entrypoints.is_a?(Array) && entrypoints.any?
        args.concat(entrypoints)
      elsif cfg['entrypoint'].is_a?(String) && !cfg['entrypoint'].empty?
        args << cfg['entrypoint']
      end

      args << "--outdir=#{cfg['outdir']}" if cfg['outdir']
      args.concat(build_flags(env))

      args
    end

    private

      def config_path
        if defined?(Rails) && Rails.respond_to?(:root)
          Rails.root.join("config", "railpack.yml")
        else
          Pathname.new("config/railpack.yml")
        end
      end

      def load_config
        if config_path.exist?
          YAML.safe_load(File.read(config_path), permitted_classes: [], aliases: false)
        else
          default_config
        end
      rescue Psych::SyntaxError => e
        raise Error, "Invalid YAML in #{config_path}: #{e.message}"
      end

      def default_config
        {
          "default" => {
            "bundler" => "bun",
            "target" => "browser",
            "format" => "esm",
            "minify" => false,
            "sourcemap" => false,
            "entrypoint" => "./app/javascript/application.js",
            "outdir" => "app/assets/builds"
          },
          "bun" => {
            "target" => "browser",
            "format" => "esm"
          },
          "esbuild" => {
            "target" => "browser",
            "format" => "esm",
            "platform" => "browser"
          },
          "rollup" => {
            "format" => "esm",
            "sourcemap" => true
          },
          "webpack" => {
            "mode" => "production",
            "target" => "web"
          },
          "development" => {
            "sourcemap" => true
          },
          "production" => {
            "minify" => true,
            "sourcemap" => false,
            "analyze_bundle" => false
          }
        }
      end

      def deep_merge(hash1, hash2)
        hash1.merge(hash2) do |key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end

      def validate_config!(config, env)
        # Validate critical config values in production
        if env.to_s == 'production'
          if config['outdir'].nil? || config['outdir'].to_s.empty?
            raise Error, "Production config must specify 'outdir'"
          end

          bundler_name = config['bundler']
          if bundler_name.nil? || bundler_name.to_s.empty?
            raise Error, "Production config must specify 'bundler'"
          end
        end

        # Validate bundler name exists in known bundlers
        bundler_name = config['bundler']
        if bundler_name && !@config.key?(bundler_name)
          message = "Unknown bundler '#{bundler_name}'. Known bundlers: #{@config.keys.grep(/^(bun|esbuild|rollup|webpack)$/).join(', ')}"
          if ENV['RAILPACK_STRICT']
            raise Error, message
          else
            Railpack.logger.warn(message)
          end
        end
      end

      def deep_freeze(object)
        case object
        when Hash
          object.each_value { |v| deep_freeze(v) }.freeze
        when Array
          object.each { |v| deep_freeze(v) }.freeze
        else
          object.freeze
        end
      end
  end
end