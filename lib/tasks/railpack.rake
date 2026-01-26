# Railpack convenience tasks for Rails
require "railpack"

# Rails asset pipeline integration - must be in rake file for Docker build
Railpack::Manager.enhance("build", "copy_assets")

namespace :railpack do
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