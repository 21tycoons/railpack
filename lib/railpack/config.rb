require "yaml"

module Railpack
  class Config
    class Error < StandardError; end

    attr_reader :config

    def initialize
      @config = load_config
    end

    def for_environment(env = Rails.env)
      base_config = @config["default"] || {}
      bundler_config = bundler_config(env)
      env_config = @config[env.to_s] || {}

      # Merge: default <- bundler <- environment
      deep_merge(deep_merge(base_config, bundler_config), env_config)
    end

    def bundler(env = Rails.env)
      for_environment(env)['bundler'] || 'bun'
    end

    def bundler_config(env = Rails.env)
      bundler_name = bundler(env)
      @config[bundler_name] || {}
    end

    def method_missing(method, *args)
      config_key = method.to_s
      if method.end_with?('=')
        # Setter - allow initializer to override config
        key = config_key.chomp('=')
        @config[Rails.env.to_s] ||= {}
        @config[Rails.env.to_s][key] = args.first
      else
        # Getter - read from merged config
        env = args.first || Rails.env
        return for_environment(env)[config_key] if for_environment(env).key?(config_key)
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      config_key = method.to_s.chomp('=')
      env = Rails.env
      for_environment(env).key?(config_key) || super
    end

    # Build command flags from config
    def build_flags(env = Rails.env)
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
    def build_args(env = Rails.env)
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
      Rails.root.join("config", "railpack.yml")
    end

    def load_config
      if config_path.exist?
        YAML.safe_load(File.read(config_path), aliases: true)
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
        "development" => {
          "sourcemap" => true
        },
        "production" => {
          "minify" => true
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
  end
end