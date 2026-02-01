namespace :railpack do
  desc "Install dependencies for the configured bundler"
  task install: :environment do
    Railpack.manager.install!
    Railpack.logger.info "Dependencies installed for #{Railpack.config.bundler}"
  end

  desc "Build assets with the configured bundler"
  task build: :environment do
    Railpack.manager.build!
  end

  desc "Watch assets for changes (development)"
  task watch: :environment do
    Railpack.manager.watch
  end

  desc "Reload Railpack configuration from YAML"
  task reload: :environment do
    Railpack.reload!
    puts "✅ Railpack configuration reloaded"
  end
end

# Hook into Rails asset pipeline (exactly like jsbundling-rails)
if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance(["railpack:install", "railpack:build"])
end

# Optional but recommended: Hook into tests (ensures dependencies in CI)
if Rake::Task.task_defined?("test:prepare")
  Rake::Task["test:prepare"].enhance(["railpack:install"])
end

# Optional: Hook into dev server if using bin/dev (like jsbundling)
if Rake::Task.task_defined?("dev")
  Rake::Task["dev"].enhance do
    Rake::Task["railpack:watch"].invoke
  end
end