class Railpack::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def create_config
    if File.exist?(Rails.root.join("config/railpack.yml"))
      say "Railpack config already exists—skipping creation", :yellow
    else
      template "railpack.yml.tt", "config/railpack.yml"
      say "Created config/railpack.yml (Bun default—edit to switch bundlers)", :green
    end
  end

  def install_dependencies
    say "Installing initial dependencies...", :green
    rake "railpack:install"  # Safe—runs the new Rake task
  end

  def setup_procfile_dev
    procfile_path = Rails.root.join("Procfile.dev")
    unless File.exist?(procfile_path) && File.read(procfile_path).include?("railpack:watch")
      append_to_file procfile_path, "js: bin/rails railpack:watch\n"
      say "Added js: bin/rails railpack:watch to Procfile.dev for live reload", :green
    end
  end

  def post_install_message
    say <<~MSG, :green

      Railpack installed successfully!

      Commands:
      - bin/rails railpack:install   # Install/update dependencies (auto-runs on deploy)
      - bin/rails railpack:build     # Build assets
      - bin/rails railpack:watch     # Live reload in development

      Switch bundler anytime in config/railpack.yml—no reinstall needed!
      Assets auto-build on deploy (hooked into assets:precompile).
      Live reload ready with bin/dev (Procfile.dev configured).

      Enjoy the flexibility! 🚀
    MSG
  end
end