# frozen_string_literal: true

require_relative "lib/railpack/version"

Gem::Specification.new do |spec|
  spec.name = "railpack"
  spec.version = Railpack::VERSION
  spec.authors = ["21tycoons LLC"]
  spec.email = ["hello@21tycoons.com"]

  spec.summary = "Multi-bundler asset pipeline for Rails"
  spec.description = "Choose your JavaScript bundler - Bun, esbuild, Rollup, Webpack. Unified Rails integration with hot module replacement and production builds."
  spec.homepage = "https://github.com/21tycoons/railpack"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/21tycoons/railpack"
  # spec.metadata["changelog_uri"] = "https://github.com/21tycoons/railpack/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
