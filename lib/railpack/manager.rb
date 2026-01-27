require 'digest'
require 'pathname'
require 'zlib'

module Railpack
  # Rails asset pipeline manager for multi-bundler support.
  #
  # This class provides a unified interface for building, watching, and managing
  # assets with different bundlers (bun, esbuild, rollup, webpack). It handles:
  # - Build lifecycle management with timing and logging
  # - Asset manifest generation for Rails asset pipeline integration
  # - Bundle size analysis and reporting
  # - Error handling and recovery
  # - Hook system for extensibility
  #
  # The manager automatically detects the Rails asset pipeline type (Propshaft/Sprockets)
  # and generates appropriate manifests for asset discovery.
  class Manager
    BUNDLERS = {
      'bun' => BunBundler,
      'esbuild' => EsbuildBundler,
      'rollup' => RollupBundler,
      'webpack' => WebpackBundler
    }

    def initialize
      @bundler = create_bundler
    end

    # Unified API - delegate to the selected bundler
    def build!(args = [])
      start_time = Time.now
      config = Railpack.config.for_environment(Rails.env)
      Railpack.trigger_build_start(config)

      begin
        Railpack.logger.info "🚀 Starting #{config['bundler']} build for #{Rails.env} environment"
        result = @bundler.build!(args)
        duration = ((Time.now - start_time) * 1000).round(2)

        # Calculate bundle size if output directory exists
        bundle_size = calculate_bundle_size(config)

        success_result = {
          success: true,
          config: config,
          duration: duration,
          bundle_size: bundle_size
        }

        Railpack.logger.info "✅ Build completed successfully in #{duration}ms (#{bundle_size})"

        # Generate asset manifest for Rails
        generate_asset_manifest(config)

        Railpack.trigger_build_complete(success_result)
        result
      rescue => error
        duration = ((Time.now - start_time) * 1000).round(2)
        Railpack.logger.error "❌ Build failed after #{duration}ms: #{error.message}"

        error_result = {
          success: false,
          error: error,
          config: config,
          duration: duration
        }

        Railpack.trigger_error(error)
        Railpack.trigger_build_complete(error_result)
        raise
      end
    end

    def watch(args = [])
      @bundler.watch(args)
    end

    def install!(args = [])
      @bundler.install!(args)
    end

    def add(*packages)
      @bundler.add(*packages)
    end

    def remove(*packages)
      @bundler.remove(*packages)
    end

    def exec(*args)
      @bundler.exec(*args)
    end

    def version
      @bundler.version
    end

    def installed?
      @bundler.installed?
    end

    # Rails asset pipeline integration
    def self.enhance_assets_precompile(*tasks, &block)
      if defined?(Rake::Task) && Rake::Task.task_defined?("assets:precompile")
        Rake::Task["assets:precompile"].enhance(tasks, &block)
      end
    end

    # Alias for convenience
    singleton_class.alias_method :enhance, :enhance_assets_precompile

    private

    def create_bundler
      bundler_name = Railpack.config.bundler
      bundler_class = BUNDLERS[bundler_name]

      unless bundler_class
        raise Error, "Unsupported bundler: #{bundler_name}. Available: #{BUNDLERS.keys.join(', ')}"
      end

      bundler_class.new(Railpack.config)
    end

    # Calculate human-readable bundle size with optional gzip compression
    def calculate_bundle_size(config)
      outdir = config['outdir']
      return 'unknown' unless outdir && Dir.exist?(outdir)

      total_size = 0
      Dir.glob("#{outdir}/**/*.{js,css,map}").each do |file|
        total_size += File.size(file) if File.file?(file)
      end

      human_size(total_size)
    rescue => error
      Railpack.logger.debug "Bundle size calculation failed: #{error.message}"
      'unknown'
    end

    # Convert bytes to human-readable format (B, KB, MB, GB)
    def human_size(bytes)
      units = %w[B KB MB GB]
      size = bytes.to_f
      units.each do |unit|
        return "#{(size).round(2)} #{unit}" if size < 1024
        size /= 1024
      end
    end

    def generate_asset_manifest(config)
      outdir = config['outdir']
      return unless outdir && Dir.exist?(outdir)

      # Detect asset pipeline type and delegate to appropriate manifest generator
      pipeline_type = detect_asset_pipeline
      manifest_class = Railpack::Manifest.const_get(pipeline_type.capitalize)

      manifest_class.generate(config)
    rescue => error
      Railpack.logger.warn "⚠️  Failed to generate asset manifest: #{error.message}"
    end

    private

    def detect_asset_pipeline
      # Check Rails.application.config.assets class directly (more reliable)
      if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
        assets_config = Rails.application.config.assets
        if assets_config.is_a?(Propshaft::Assembler) || defined?(Propshaft::Assembler)
          :propshaft
        elsif defined?(Sprockets::Manifest)
          :sprockets
        end
      end

      # Fallback to version-based detection
      if defined?(Rails) && Rails.version.to_f >= 7.0
        :propshaft
      elsif defined?(Rails) && Rails.version.to_f < 7.0 && defined?(Sprockets)
        :sprockets
      else
        # Safe default for modern Rails
        :propshaft
      end
    end


  end
end