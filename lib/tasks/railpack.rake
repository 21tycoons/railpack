# Railpack convenience tasks for Rails
require "railpack"

# Rails asset pipeline integration - must be in rake file for Docker build
Railpack::Manager.enhance("build", "copy_assets")

namespace :railpack do
  desc "Install and setup Railpack with default configuration"
  task :install do
    config_path = Rails.root.join("config/railpack.yml")

    if config_path.exist?
      puts "Railpack config already exists at #{config_path}"
      puts "Run 'rails railpack:install:force' to overwrite"
    else
      create_config_file(config_path)
      puts "✅ Created Railpack configuration at #{config_path}"
      puts "🎯 Run 'rails railpack:install' to install bundler dependencies"
    end
  end

  desc "Force install Railpack configuration (overwrites existing)"
  task "install:force" do
    config_path = Rails.root.join("config/railpack.yml")
    create_config_file(config_path)
    puts "✅ Created/Updated Railpack configuration at #{config_path}"
    puts "🎯 Run 'rails railpack:install' to install bundler dependencies"
  end

  desc "Install Railpack dependencies"
  task :install do
    Railpack.install!
  end

  desc "Build JavaScript for production"
  task :build do
    Railpack.build!
  end

  desc "Watch and rebuild JavaScript"
  task :watch do
    Railpack.watch
  end

  desc "Clean built assets"
  task :clean do
    # TODO: Implement clean
  end

  desc "Add Railpack dependencies"
  task :add, [ :packages ] do |t, args|
    packages = args[:packages].split(" ")
    Railpack.add(*packages)
  end

  desc "Remove Railpack dependencies"
  task :remove, [ :packages ] do |t, args|
    packages = args[:packages].split(" ")
    Railpack.remove(*packages)
  end

  desc "Copy built assets to public/assets for Rails serving"
  task :copy_assets do
    builds_dir = Rails.root.join("app/assets/builds")
    public_assets_dir = Rails.root.join("public/assets")

    if builds_dir.exist?
      FileUtils.mkdir_p(public_assets_dir)
      Dir.glob("#{builds_dir}/*.{js,map}").each do |file|
        FileUtils.cp(file, public_assets_dir)
      end
      puts "Copied #{Dir.glob("#{builds_dir}/*.{js,map}").size} assets to public/assets"
    else
      puts "No builds directory found"
    end
  end

  desc "Show Railpack version"
  task :version do
    puts Railpack.version
  end

  desc "Check if Railpack bundler is installed"
  task :installed do
    puts Railpack.installed? ? "Yes" : "No"
  end

  desc "Show current bundler"
  task :bundler do
    puts "Current bundler: #{Railpack.config.bundler}"
  end
end

def create_config_file(config_path)
  config_content = <<~YAML
    # Railpack Configuration
    # Choose your bundler: bun, esbuild, rollup, webpack

    bundler: bun  # Default bundler

    # Global defaults
    default:
      target: browser
      format: esm
      minify: false
      sourcemap: false
      entrypoint: "./app/javascript/application.js"
      outdir: "app/assets/builds"

    # Bundler-specific configurations
    bun:
      target: browser
      format: esm

    esbuild:
      target: browser
      format: esm
      platform: browser

    rollup:
      format: esm
      sourcemap: true

    webpack:
      mode: production
      target: web

    # Environment-specific overrides
    development:
      sourcemap: true

    production:
      minify: true
      sourcemap: false
      analyze_bundle: false
  YAML

  File.write(config_path, config_content)
end
