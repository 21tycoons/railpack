require 'shellwords'
require 'open3'

module Railpack
  class Bundler
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def build!(args = [])
      raise NotImplementedError, "#{self.class.name} must implement #build!"
    end

    def watch(args = [])
      raise NotImplementedError, "#{self.class.name} must implement #watch"
    end

    def install!(args = [])
      raise NotImplementedError, "#{self.class.name} must implement #install!"
    end

    def add(*packages)
      raise NotImplementedError, "#{self.class.name} must implement #add"
    end

    def remove(*packages)
      raise NotImplementedError, "#{self.class.name} must implement #remove"
    end

    def exec(*args)
      raise NotImplementedError, "#{self.class.name} must implement #exec"
    end

    def version
      raise NotImplementedError, "#{self.class.name} must implement #version"
    end

    def installed?
      raise NotImplementedError, "#{self.class.name} must implement #installed?"
    end

    def name
      self.class.name.split('::').last.sub('Bundler', '').downcase
    end

    def base_command
      raise NotImplementedError, "#{self.class.name} must implement #base_command"
    end

    def commands
      @commands ||= begin
        defaults = default_commands
        overrides = bundler_command_overrides
        defaults.merge(overrides)
      end
    end

    def default_commands
      raise NotImplementedError, "#{self.class.name} must implement #default_commands"
    end

    private

      def bundler_command_overrides
        return {} unless config.respond_to?(:bundler_command_overrides)

        begin
          config.bundler_command_overrides(current_env) || {}
        rescue NoMethodError, KeyError, TypeError, ArgumentError => e
          # Log warning for legitimate config issues, but don't crash
          if defined?(Rails) && Rails.logger
            Rails.logger.warn "Railpack: Invalid bundler_command_overrides config (#{e.class}: #{e.message}) - using defaults"
          end
          {}
        rescue => e
          # Re-raise unexpected errors (don't hide bugs)
          raise e
        end
      end

      def current_env
        if defined?(Rails) && Rails.respond_to?(:env)
          Rails.env
        else
          :development
        end
      end

    protected

      def execute(command_array)
        if respond_to?(:base_command)
          system(base_command, *command_array)
        else
          system(*command_array)
        end
      end

      def execute!(command_array)
        if respond_to?(:base_command)
          stdout, stderr, status = Open3.capture3(base_command, *command_array)
        else
          stdout, stderr, status = Open3.capture3(*command_array)
        end

        unless status.success?
          command_string = Shellwords.join(command_array)

          error_msg = "Command failed"
          error_msg += " (exit status: #{status.exitstatus})" if status.exitstatus
          error_msg += " (terminated by signal: #{status.termsig})" if status.termsig
          error_msg += ": #{command_string}"

          # Include stderr output for debugging (truncate if too long)
          if stderr && !stderr.empty?
            stderr_lines = stderr.split("\n")
            if stderr_lines.size > 10
              stderr_preview = stderr_lines.first(5).join("\n") + "\n... (#{stderr_lines.size - 5} more lines)"
            else
              stderr_preview = stderr
            end
            error_msg += "\n\nSTDERR:\n#{stderr_preview}"
          end

          raise Error, error_msg
        end

        status.success?
      end

      # Build full command args by merging config flags/args with passed args
      def build_command_args(operation, args = [])
        env = current_env
        if config.respond_to?("#{operation}_args")
          config_args = config.send("#{operation}_args", env) || []
          config_flags = config.send("#{operation}_flags", env) || []
          config_args + config_flags + args
        else
          # Fallback for hash configs (used in tests)
          args
        end
      end
  end

  # Intermediate base class for NPM-based bundlers (esbuild, rollup, webpack)
  class NpmBasedBundler < Bundler
    def package_manager
      @package_manager ||= detect_package_manager
    end

    def install!(args = [])
      execute([package_manager, "install", *args])
    end

    def add(*packages)
      execute([package_manager, "install", *packages])
    end

    def remove(*packages)
      execute([package_manager, "uninstall", *packages])
    end

    def exec(*args)
      execute([package_manager, "exec", *args])
    end

    def version
      `#{commands[:version]}`.strip
    end

    def installed?
      system("#{commands[:version]} > /dev/null 2>&1")
    end

    private

      def detect_package_manager
        return "yarn" if File.exist?("yarn.lock")
        return "pnpm" if File.exist?("pnpm-lock.yaml") || File.exist?("pnpm-workspace.yaml")
        "npm" # default fallback
      end
  end
end
