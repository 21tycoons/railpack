require 'digest'
require 'pathname'
require 'json'

module Railpack
  # Manifest generation for different Rails asset pipelines.
  #
  # This module provides manifest generation for Propshaft (Rails 7+) and
  # Sprockets (Rails < 7) asset pipelines, ensuring built assets are properly
  # discoverable by Rails for serving and asset path helpers.
  module Manifest
    # Propshaft manifest generator for Rails 7+.
    # Creates a simple JSON manifest mapping logical paths to physical files.
    class Propshaft
      def self.generate(config)
        outdir = config['outdir']
        return unless outdir && Dir.exist?(outdir)

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
    end

    # Sprockets manifest generator for Rails < 7.
    # Creates a detailed manifest with digested filenames and asset mappings.
    class Sprockets
      def self.generate(config)
        outdir = config['outdir']
        return unless outdir && Dir.exist?(outdir)

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
end