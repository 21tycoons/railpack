require 'digest'
require 'fileutils'
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
      'bun'     => BunBundler,
      'esbuild' => EsbuildBundler,
      'rollup'  => RollupBundler,
      'webpack' => WebpackBundler
    }

    def initialize
      @bundler = create_bundler
    end

    # Build assets using the configured bundler.
    #
    # This method orchestrates the complete build lifecycle:
    # 1. Triggers build_start hooks
    # 2. Validates output directory exists
    # 3. Executes bundler build command
    # 4. Calculates bundle size and timing
    # 5. Generates asset manifest for Rails
    # 6. Triggers build_complete hooks
    #
    # @param args [Array] Additional arguments to pass to the bundler
    # @return [Object] Result from the bundler build command
    # @raise [Error] If build fails or configuration is invalid
    def build!(args = [])
      start_time = Time.now
      config = Railpack.config.for_environment(Rails.env)
      Railpack.trigger_build_start(config)

      # Pre-build validation: warn if output directory issues
      validate_output_directory(config)

      begin
        Railpack.logger.info "🚀 Starting #{config['bundler']} build for #{Rails.env} environment"
        result = @bundler.build!(args)
        duration = ((Time.now - start_time) * 1000).round(2)

        # Calculate bundle size if output directory exists
        bundle_size = calculate_bundle_size(config)

        # Build result hash passed to build_complete hooks
        # Contains: success status, config used, build duration, and bundle size
        success_result = {
          success: true,
          config: config,
          duration: duration,
          bundle_size: bundle_size
        }

        Railpack.logger.info "✅ Build completed successfully in #{duration}ms (#{bundle_size})"

        # Generate asset manifest for Rails
        generate_asset_manifest(config)

        # Trigger build_complete hooks with success result
        Railpack.trigger_build_complete(success_result)
        result
      rescue => error
        duration = ((Time.now - start_time) * 1000).round(2)
        Railpack.logger.error "❌ Build failed after #{duration}ms: #{error.message}"

        # Error result hash passed to build_complete hooks
        # Contains: failure status, error object, config used, and build duration
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

        # Include gzip size if analyze_bundle is enabled
        if config['analyze_bundle']
          gzip_size = calculate_gzip_size(outdir)
          "#{human_size(total_size)} (#{human_size(gzip_size)} gzipped)"
        else
          human_size(total_size)
        end
      rescue => error
        Railpack.logger.debug "Bundle size calculation failed: #{error.message}"
        'unknown'
      end

      # Calculate total gzip-compressed size of assets
      def calculate_gzip_size(outdir)
        Dir.glob("#{outdir}/**/*.{js,css}").sum do |file|
          next 0 unless File.file?(file)
          Zlib::Deflate.deflate(File.read(file)).bytesize
        end
      rescue => error
        Railpack.logger.debug "Gzip size calculation failed: #{error.message}"
        0
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
        # Enhanced error logging with context
        asset_files = Dir.glob("#{outdir}/**/*.{js,css}").length rescue 0
        Railpack.logger.warn "⚠️  Failed to generate #{pipeline_type} asset manifest for #{outdir} (#{asset_files} assets): #{error.message}"
      end

      # Validate output directory exists and is writable before build
      def validate_output_directory(config)
        outdir = config['outdir']
        return unless outdir

        unless Dir.exist?(outdir)
          Railpack.logger.warn "⚠️  Output directory #{outdir} does not exist - assets will be created on first build"
          # Ensure directory exists to prevent early build failures
          FileUtils.mkdir_p(outdir)
        end
      end

      def detect_asset_pipeline
        # Check Rails.application.config.assets class directly (more reliable)
        if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
          assets_config = Rails.application.config.assets
          begin
            if defined?(Propshaft) && Propshaft.const_defined?(:Assembler) && assets_config.is_a?(Propshaft::Assembler)
              return :propshaft
            end
          rescue NameError
            # Propshaft::Assembler not available
          end
          if defined?(Sprockets::Manifest)
            return :sprockets
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
