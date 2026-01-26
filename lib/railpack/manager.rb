require 'digest'
require 'pathname'

module Railpack
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

        Railpack.logger.info "✅ Build completed successfully in #{duration}ms (#{bundle_size}kb)"

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
    def self.enhance_assets_precompile(*tasks)
      if defined?(Rake::Task) && Rake::Task.task_defined?("assets:precompile")
        Rake::Task["assets:precompile"].enhance(tasks)
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

    def calculate_bundle_size(config)
      outdir = config['outdir']
      return 'unknown' unless outdir && Dir.exist?(outdir)

      total_size = 0
      Dir.glob("#{outdir}/**/*.{js,css,map}").each do |file|
        total_size += File.size(file) if File.file?(file)
      end

      (total_size / 1024.0).round(2)
    rescue
      'unknown'
    end

    def generate_asset_manifest(config)
      outdir = config['outdir']
      return unless outdir && Dir.exist?(outdir)

      manifest = {}

      # Find built assets - Propshaft format
      Dir.glob("#{outdir}/**/*.{js,css}").each do |file|
        next unless File.file?(file)
        relative_path = Pathname.new(file).relative_path_from(Pathname.new(outdir)).to_s

        # Map logical names to physical files (Propshaft style)
        if relative_path.include?('application') && relative_path.end_with?('.js')
          manifest['application.js'] = {
            'logical_path' => 'application.js',
            'pathname' => Pathname.new(relative_path),
            'digest' => Digest::MD5.file(file).hexdigest
          }
        elsif relative_path.include?('application') && relative_path.end_with?('.css')
          manifest['application.css'] = {
            'logical_path' => 'application.css',
            'pathname' => Pathname.new(relative_path),
            'digest' => Digest::MD5.file(file).hexdigest
          }
        end
      end

      # Write manifest for Propshaft (Rails 7+ default)
      manifest_path = "#{outdir}/.manifest.json"
      File.write(manifest_path, JSON.pretty_generate(manifest))
      Railpack.logger.debug "📄 Generated Propshaft manifest: #{manifest_path}"
    rescue => error
      Railpack.logger.warn "⚠️  Failed to generate asset manifest: #{error.message}"
    end
  end
end