# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'railpack'

class ConfigTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @original_rails_root = nil
    if defined?(Rails) && Rails.respond_to?(:root)
      @original_rails_root = Rails.singleton_class.instance_method(:root)
    end
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
    # Restore original Rails.root method if it was overridden
    if @original_rails_root && defined?(Rails)
      Rails.singleton_class.define_method(:root, @original_rails_root)
    end
  end

  def test_config_initialization
    config = Railpack::Config.new
    assert_instance_of Railpack::Config, config
    assert_respond_to config, :bundler
    assert_respond_to config, :entrypoint
  end

  def test_config_default_values
    config = Railpack::Config.new
    assert_equal 'bun', config.bundler
    assert_equal './app/javascript/application.js', config.entrypoint
    assert_equal 'app/assets/builds', config.outdir
  end

  def test_config_build_flags_unit
    config = Railpack::Config.new

    # Test build_flags with different environments
    dev_flags = config.build_flags('development')
    prod_flags = config.build_flags('production')

    # Development should have sourcemap
    assert_includes dev_flags, '--sourcemap'
    # Production should have minify
    assert_includes prod_flags, '--minify'
  end

  def test_config_build_args_unit
    config = Railpack::Config.new

    args = config.build_args('development')
    assert_includes args, './app/javascript/application.js'
    assert_includes args, '--outdir=app/assets/builds'
    assert_includes args, '--target=browser'
    assert_includes args, '--format=esm'
  end

  def test_config_bundler_method
    config = Railpack::Config.new

    # Test bundler method with different environments
    assert_equal 'bun', config.bundler('development')
    assert_equal 'bun', config.bundler('production')
  end

  def test_config_for_environment_unit
    config = Railpack::Config.new

    dev_config = config.for_environment('development')
    prod_config = config.for_environment('production')

    # Check that environment-specific settings are applied
    assert_equal true, dev_config['sourcemap']
    assert_equal true, prod_config['minify']
    assert_equal false, prod_config['sourcemap']
  end

  def test_config_yaml_file_loading
    # Test that Railpack can load config from a YAML file
    config_dir = File.join(@temp_dir, 'config')
    FileUtils.mkdir_p(config_dir)
    config_file = File.join(config_dir, 'railpack.yml')

    File.write(config_file, <<~YAML)
      default:
        bundler: rollup
        target: node
        format: cjs
        entrypoint: "./server.js"
        outdir: "dist"
        minify: false
      development:
        sourcemap: true
      production:
        minify: true
        sourcemap: false
    YAML

    # Verify the file was created
    assert File.exist?(config_file), "Config file should exist at #{config_file}"

    # Mock Rails.root to point to our temp directory
    mock_rails_root(@temp_dir)

    # Create a fresh config instance to test file loading
    config = Railpack::Config.new

    # Test that the YAML file was loaded correctly
    assert_equal 'rollup', config.bundler
    assert_equal './server.js', config.entrypoint
    assert_equal 'dist', config.outdir
    assert_equal 'node', config.target
    assert_equal 'cjs', config.format
    assert_equal false, config.minify

    # Test environment overrides
    dev_config = config.for_environment('development')
    prod_config = config.for_environment('production')

    assert_equal true, dev_config['sourcemap']
    assert_equal true, prod_config['minify']
    assert_equal false, prod_config['sourcemap']
  end

  def test_config_environment_overrides
    # Test environment override logic with default config
    config = Railpack::Config.new
    dev_config = config.for_environment('development')
    prod_config = config.for_environment('production')

    # Development should have sourcemap enabled by default
    assert_equal true, dev_config['sourcemap']
    # Production should have minify enabled by default
    assert_equal true, prod_config['minify']
  end

  def test_config_error_handling
    # Test config error handling for invalid YAML
    config_dir = File.join(@temp_dir, 'config')
    FileUtils.mkdir_p(config_dir)
    config_file = File.join(config_dir, 'railpack.yml')
    File.write(config_file, "invalid: yaml: content: [")

    mock_rails_root(@temp_dir)

    # This should raise an error for invalid YAML
    assert_raises(Railpack::Config::Error) do
      Railpack::Config.new
    end
  end

  def test_config_method_missing
    config = Railpack::Config.new

    # Test that config responds to dynamic methods
    assert_respond_to config, :target
    assert_respond_to config, :format
    assert_equal 'browser', config.target
    assert_equal 'esm', config.format
  end

  private

  def mock_rails_root(path)
    rails_module = if defined?(Rails)
                     Rails
                   else
                     Object.const_set(:Rails, Module.new)
                   end

    rails_module.define_singleton_method(:root) { Pathname.new(path) }
    rails_module.define_singleton_method(:env) { 'development' }
  end
end