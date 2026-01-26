# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'railpack'

class ManagerTest < Minitest::Test
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

  def test_manager_initialization
    manager = Railpack::Manager.new
    assert_instance_of Railpack::Manager, manager
    assert_respond_to manager, :build!
    assert_respond_to manager, :watch
    assert_respond_to manager, :install!
  end

  def test_manager_bundler_creation
    manager = Railpack::Manager.new
    bundler = manager.send(:create_bundler)
    assert_instance_of Railpack::BunBundler, bundler
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

  def test_manager_bundle_size_calculation_empty_directory
    # Test with empty directory
    outdir = File.join(@temp_dir, 'empty_builds')
    FileUtils.mkdir_p(outdir)

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    size = manager.send(:calculate_bundle_size, config)
    assert_equal 0.0, size
  end

  def test_manager_bundle_size_calculation_nonexistent_directory
    manager = Railpack::Manager.new
    config = { 'outdir' => '/nonexistent/directory' }

    size = manager.send(:calculate_bundle_size, config)
    assert_equal 'unknown', size
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
    assert manifest['application.js']['pathname'].end_with?('application.js')
    assert manifest['application.js']['digest']
  end

  def test_manager_asset_manifest_generation_no_assets
    outdir = File.join(@temp_dir, 'empty_builds')
    FileUtils.mkdir_p(outdir)

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    assert File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))
    assert_empty manifest
  end

  def test_manager_build_with_config
    manager = Railpack::Manager.new

    # Mock the bundler to avoid actual command execution
    mock_bundler = Minitest::Mock.new
    mock_bundler.expect(:build!, true, [[]])
    manager.instance_variable_set(:@bundler, mock_bundler)

    # Mock Rails.env to avoid dependency
    rails_module = if defined?(Rails)
                     Rails
                   else
                     Object.const_set(:Rails, Module.new)
                   end
    rails_module.define_singleton_method(:env) { 'development' }

    result = manager.build!
    assert result

    mock_bundler.verify
  end

  def test_manager_install_with_config
    manager = Railpack::Manager.new

    # Mock the bundler to avoid actual command execution
    mock_bundler = Minitest::Mock.new
    mock_bundler.expect(:install!, true, [[]])
    manager.instance_variable_set(:@bundler, mock_bundler)

    result = manager.install!
    assert result

    mock_bundler.verify
  end

  def test_manager_watch_with_config
    manager = Railpack::Manager.new

    # Mock the bundler to avoid actual command execution
    mock_bundler = Minitest::Mock.new
    mock_bundler.expect(:watch, nil, [[]])
    manager.instance_variable_set(:@bundler, mock_bundler)

    manager.watch

    mock_bundler.verify
  end

  def test_manager_bundler_constants
    assert_equal Railpack::BunBundler, Railpack::Manager::BUNDLERS['bun']
    assert_equal Railpack::EsbuildBundler, Railpack::Manager::BUNDLERS['esbuild']
    assert_equal Railpack::RollupBundler, Railpack::Manager::BUNDLERS['rollup']
    assert_equal Railpack::WebpackBundler, Railpack::Manager::BUNDLERS['webpack']
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