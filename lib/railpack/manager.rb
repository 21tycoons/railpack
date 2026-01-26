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

      # Detect asset pipeline type
      pipeline_type = detect_asset_pipeline

      case pipeline_type
      when :propshaft
        generate_propshaft_manifest(config)
      when :sprockets
        generate_sprockets_manifest(config)
      else
        # Default to Propshaft for Rails 7+
        generate_propshaft_manifest(config)
      end
    rescue => error
      Railpack.logger.warn "⚠️  Failed to generate asset manifest: #{error.message}"
    end

    private

    def detect_asset_pipeline
      # Check for Propshaft (Rails 7+ default)
      if defined?(Propshaft) || (defined?(Rails) && Rails.version.to_f >= 7.0)
        :propshaft
      # Check for Sprockets (only if Rails < 7)
      elsif defined?(Sprockets) && defined?(Rails) && Rails.version.to_f < 7.0
        :sprockets
      else
        # Default to Propshaft for modern Rails or when no Rails is detected
        :propshaft
      end
    end

    def generate_propshaft_manifest(config)
      outdir = config['outdir']
      manifest = {}

      # Find built assets - Propshaft format
      Dir.glob("#{outdir}/**/*.{js,css}").each do |file|
        next unless File.file?(file)
        relative_path = Pathname.new(file).relative_path_from(Pathname.new(outdir)).to_s

        # Use relative path as logical path for Propshaft
        logical_path = relative_path
        manifest[logical_path] = {
          'logical_path' => logical_path,
          'pathname' => relative_path,
          'digest' => Digest::MD5.file(file).hexdigest
        }
      end

      # Write manifest for Propshaft (Rails 7+ default)
      manifest_path = "#{outdir}/.manifest.json"
      File.write(manifest_path, JSON.pretty_generate(manifest))
      Railpack.logger.debug "📄 Generated Propshaft manifest: #{manifest_path}"
    end

    def generate_sprockets_manifest(config)
      outdir = config['outdir']
      manifest = {
        'files' => {},
        'assets' => {}
      }

      # Find built assets - Sprockets format
      Dir.glob("#{outdir}/**/*.{js,css}").each do |file|
        next unless File.file?(file)
        relative_path = Pathname.new(file).relative_path_from(Pathname.new(outdir)).to_s

        # Generate digest for Sprockets format
        digest = Digest::MD5.file(file).hexdigest
        logical_path = relative_path

        # Map logical names (Sprockets style) - only for application files
        if relative_path.include?('application') && relative_path.end_with?('.js')
          manifest['assets']['application.js'] = "#{digest}-#{File.basename(relative_path)}"
          logical_path = 'application.js'
        elsif relative_path.include?('application') && relative_path.end_with?('.css')
          manifest['assets']['application.css'] = "#{digest}-#{File.basename(relative_path)}"
          logical_path = 'application.css'
        else
          # For non-application files, still add to files but not to assets mapping
          logical_path = relative_path
        end

        # Add file entry for all files
        manifest['files']["#{digest}-#{File.basename(relative_path)}"] = {
          'logical_path' => logical_path,
          'pathname' => relative_path,
          'digest' => digest,
          'size' => File.size(file),
          'mtime' => File.mtime(file).iso8601
        }
      end

      # Write manifest for Sprockets (Rails < 7)
      manifest_path = "#{outdir}/.sprockets-manifest-#{Digest::MD5.hexdigest(outdir)}.json"
      File.write(manifest_path, JSON.pretty_generate(manifest))
      Railpack.logger.debug "📄 Generated Sprockets manifest: #{manifest_path}"
    end
  end
end