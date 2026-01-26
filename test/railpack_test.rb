# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'json'
require 'railpack'

class RailpackTest < Minitest::Test
  def setup
    # Create a temporary directory for testing
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

  def test_version
    refute_nil ::Railpack::VERSION
    assert_match(/\d+\.\d+\.\d+/, ::Railpack::VERSION)
  end

  def test_config_instance
    assert_instance_of Railpack::Config, Railpack.config
  end

  def test_manager_instance
    assert_instance_of Railpack::Manager, Railpack.manager
  end

  def test_bundler_support
    assert_includes Railpack::Manager::BUNDLERS.keys, 'bun'
    assert_includes Railpack::Manager::BUNDLERS.keys, 'esbuild'
    assert_includes Railpack::Manager::BUNDLERS.keys, 'rollup'
    assert_includes Railpack::Manager::BUNDLERS.keys, 'webpack'
    assert_equal Railpack::BunBundler, Railpack::Manager::BUNDLERS['bun']
    assert_equal Railpack::EsbuildBundler, Railpack::Manager::BUNDLERS['esbuild']
    assert_equal Railpack::RollupBundler, Railpack::Manager::BUNDLERS['rollup']
    assert_equal Railpack::WebpackBundler, Railpack::Manager::BUNDLERS['webpack']
  end



  def test_manager_bundle_size_calculation
    # Create test output directory with fake assets
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create fake JS and CSS files
    File.write(File.join(outdir, 'app.js'), 'console.log("test");')
    File.write(File.join(outdir, 'app.css'), 'body { color: red; }')
    File.write(File.join(outdir, 'app.js.map'), '{"version":3}')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    size = manager.send(:calculate_bundle_size, config)
    assert size.is_a?(Float)
    assert size > 0
  end

  def test_manager_asset_manifest_generation
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create fake built assets
    File.write(File.join(outdir, 'application.js'), 'console.log("app");')
    File.write(File.join(outdir, 'application.css'), 'body { color: blue; }')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    assert File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))
    assert manifest.key?('application.js')
    assert manifest.key?('application.css')
    assert manifest['application.js']['logical_path'] == 'application.js'
  end

  def test_bundler_base_class
    bundler = Railpack::Bundler.new({})

    assert_respond_to bundler, :build!
    assert_respond_to bundler, :watch
    assert_respond_to bundler, :install!
    assert_respond_to bundler, :name
    assert_respond_to bundler, :commands
  end

  def test_bun_bundler_commands
    bundler = Railpack::BunBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'bun run build', commands[:build]
    assert_equal 'bun run watch', commands[:watch]
    assert_equal 'bun install', commands[:install]
  end

  def test_esbuild_bundler_commands
    bundler = Railpack::EsbuildBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'esbuild', commands[:build]
    assert_equal 'esbuild --watch', commands[:watch]
    assert_equal 'npm install', commands[:install]
  end

  def test_rollup_bundler_commands
    bundler = Railpack::RollupBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'rollup', commands[:build]
    assert_equal 'rollup --watch', commands[:watch]
    assert_equal 'npm install', commands[:install]
  end

  def test_webpack_bundler_commands
    bundler = Railpack::WebpackBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'webpack', commands[:build]
    assert_equal 'webpack --watch', commands[:watch]
    assert_equal 'npm install', commands[:install]
  end

  def test_event_hooks
    events = []
    Railpack.on_build_start { |config| events << [:start, config] }
    Railpack.on_build_complete { |result| events << [:complete, result] }

    # Trigger build to test hooks
    manager = Railpack::Manager.new
    config = Railpack.config.for_environment

    # Mock a simple build that doesn't actually execute
    manager.instance_variable_set(:@bundler, Minitest::Mock.new)
    manager.instance_variable_get(:@bundler).expect(:build!, true, [[]])

    Railpack.trigger_build_start(config)
    Railpack.trigger_build_complete({ success: true })

    assert_equal 2, events.size
    assert_equal [:start, config], events[0]
    assert_equal [:complete, { success: true }], events[1]
  end

  def test_error_handling
    error = nil
    Railpack.on_error { |err| error = err }

    begin
      raise StandardError.new("Test error")
    rescue => e
      Railpack.trigger_error(e)
    end

    assert_equal "Test error", error.message
  end

  def test_logger_integration
    # Test that logger methods exist
    assert_respond_to Railpack, :logger
    assert_respond_to Railpack, :logger=
  end

  private

  def mock_rails_root(path)
    rails_module = if defined?(Rails)
                     Rails
                   else
                     Object.const_set(:Rails, Module.new)
                   end

    rails_module.define_singleton_method(:root) { Pathname.new(path) }
  end
end
