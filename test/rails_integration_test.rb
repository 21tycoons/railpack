# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'json'
require 'railpack'

class RailsIntegrationTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @original_rails = nil
    @original_propshaft = nil
    @original_sprockets = nil

    # Store original constants
    @original_rails = Object.const_get(:Rails) if defined?(Rails)
    @original_propshaft = Object.const_get(:Propshaft) if defined?(Propshaft)
    @original_sprockets = Object.const_get(:Sprockets) if defined?(Sprockets)

    # Clear cached logger to avoid interference between tests
    Railpack.instance_variable_set(:@logger, nil)
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)

    # Clean up any constants we created
    Object.send(:remove_const, :Rails) if defined?(Rails) && Rails.name.nil?
    Object.send(:remove_const, :Propshaft) if defined?(Propshaft) && Propshaft.name.nil?
    Object.send(:remove_const, :Sprockets) if defined?(Sprockets) && Sprockets.name.nil?

    # Restore original constants
    Object.const_set(:Rails, @original_rails) if @original_rails
    Object.const_set(:Propshaft, @original_propshaft) if @original_propshaft
    Object.const_set(:Sprockets, @original_sprockets) if @original_sprockets
  end

  def test_asset_pipeline_detection_rails_7_propshaft
    # Mock Rails 7 with Propshaft
    rails_mock = Module.new
    rails_mock.define_singleton_method(:version) { '7.0.0' }
    Object.const_set(:Rails, rails_mock)

    Object.const_set(:Propshaft, Module.new)

    manager = Railpack::Manager.new
    pipeline = manager.send(:detect_asset_pipeline)

    assert_equal :propshaft, pipeline
  ensure
    Object.send(:remove_const, :Propshaft) if defined?(Propshaft)
  end

  def test_asset_pipeline_detection_rails_6_sprockets
    # Mock Rails 6 with Sprockets
    rails_mock = Module.new
    rails_mock.define_singleton_method(:version) { '6.1.0' }
    Object.const_set(:Rails, rails_mock)

    Object.const_set(:Sprockets, Module.new)

    manager = Railpack::Manager.new
    pipeline = manager.send(:detect_asset_pipeline)

    assert_equal :sprockets, pipeline
  ensure
    Object.send(:remove_const, :Sprockets) if defined?(Sprockets)
  end

  def test_asset_pipeline_detection_rails_8_no_constants
    # Mock Rails 8 without Propshaft/Sprockets constants
    rails_mock = Module.new
    rails_mock.define_singleton_method(:version) { '8.0.0' }
    Object.const_set(:Rails, rails_mock)

    manager = Railpack::Manager.new
    pipeline = manager.send(:detect_asset_pipeline)

    # Should default to Propshaft for modern Rails
    assert_equal :propshaft, pipeline
  end

  def test_asset_pipeline_detection_legacy_rails_no_constants
    # Mock Rails 5 without Propshaft/Sprockets constants
    rails_mock = Module.new
    rails_mock.define_singleton_method(:version) { '5.2.0' }
    Object.const_set(:Rails, rails_mock)

    # Ensure Sprockets is not defined for this test
    if defined?(Sprockets)
      Object.send(:remove_const, :Sprockets)
    end

    manager = Railpack::Manager.new
    pipeline = manager.send(:detect_asset_pipeline)

    # Should default to Propshaft (could be enhanced to detect Sprockets differently)
    assert_equal :propshaft, pipeline
  end

  def test_asset_pipeline_detection_no_rails
    # Remove Rails constant
    Object.send(:remove_const, :Rails) if defined?(Rails)

    manager = Railpack::Manager.new
    pipeline = manager.send(:detect_asset_pipeline)

    # Should default to Propshaft
    assert_equal :propshaft, pipeline
  end

  def test_rails_asset_precompile_enhancement
    # Test that the enhancement method exists and can be called
    assert_respond_to Railpack::Manager, :enhance_assets_precompile
    assert_respond_to Railpack::Manager, :enhance

    # Test that it doesn't raise an error when Rake is not available
    begin
      Railpack::Manager.enhance_assets_precompile do
        # Mock task
      end
      assert true # If we get here, no exception was raised
    rescue
      flunk "enhance_assets_precompile should not raise an error when Rake is not available"
    end
  end

  def test_rails_rake_task_integration
    # Mock Rake environment properly
    rake_mock = Module.new
    task_class_mock = Class.new do
      def self.task_defined?(name)
        name == "assets:precompile"
      end

      def self.[](name)
        @task_instance ||= Class.new do
          def enhance(*args, &block)
            # Store the block for verification
            @enhancement_block = block
          end

          def enhancement_block
            @enhancement_block
          end
        end.new
      end
    end

    rake_mock.const_set(:Task, task_class_mock)
    Object.const_set(:Rake, rake_mock)

    # Test that enhance_assets_precompile works with Rake available
    enhancement_executed = false
    Railpack::Manager.enhance_assets_precompile do
      enhancement_executed = true
      "Enhanced assets:precompile task"
    end

    # Verify the enhancement was registered (block should be stored)
    task_instance = Rake::Task["assets:precompile"]
    assert task_instance.enhancement_block.is_a?(Proc), "Enhancement block should be registered"

    # Execute the enhancement block manually to verify it works
    result = task_instance.enhancement_block.call
    assert_equal "Enhanced assets:precompile task", result
  ensure
    Object.send(:remove_const, :Rake) if defined?(Rake)
  end

  def test_rails_config_integration
    # Test that Railpack config works with Rails.root
    temp_dir = @temp_dir
    rails_mock = Class.new do
      define_singleton_method(:root) { Pathname.new(temp_dir) }
      define_singleton_method(:env) { 'development' }
    end

    Object.const_set(:Rails, rails_mock)

    # Create a mock railpack.yml
    config_dir = File.join(@temp_dir, 'config')
    FileUtils.mkdir_p(config_dir)
    config_content = {
      'default' => {
        'bundler' => 'bun',
        'target' => 'browser',
        'format' => 'esm'
      }
    }
    File.write(File.join(config_dir, 'railpack.yml'), config_content.to_yaml)

    # Test config loading
    config = Railpack::Config.new.for_environment
    assert_equal 'bun', config['bundler']
    assert_equal 'browser', config['target']
    assert_equal 'esm', config['format']
  end

  def test_rails_logger_integration
    # Test that Railpack uses Rails logger when available
    rails_mock = Module.new
    logger_mock = Minitest::Mock.new
    logger_mock.expect(:debug, nil, ['Test message'])
    logger_mock.expect(:info, nil, ['Info message'])
    logger_mock.expect(:warn, nil, ['Warning message'])

    rails_mock.define_singleton_method(:logger) { logger_mock }
    Object.const_set(:Rails, rails_mock)

    # Clear cached logger to force re-evaluation
    Railpack.instance_variable_set(:@logger, nil)

    # Test logger delegation
    Railpack.logger.debug 'Test message'
    Railpack.logger.info 'Info message'
    Railpack.logger.warn 'Warning message'

    logger_mock.verify
  end

  def test_rails_environment_detection
    # Test Rails.env integration
    rails_mock = Module.new
    rails_mock.define_singleton_method(:env) { 'production' }
    Object.const_set(:Rails, rails_mock)

    config_instance = Railpack::Config.new
    config = config_instance.for_environment
    # Production config should have minify: true
    assert_equal true, config['minify']
    assert_equal false, config['sourcemap']
  end

  def test_rails_root_config_loading
    # Test that config loads from Rails.root/config/railpack.yml
    temp_dir = @temp_dir
    rails_mock = Class.new do
      define_singleton_method(:root) { Pathname.new(temp_dir) }
      define_singleton_method(:env) { 'development' }
    end
    Object.const_set(:Rails, rails_mock)

    # Create config file
    config_dir = File.join(@temp_dir, 'config')
    FileUtils.mkdir_p(config_dir)

    custom_config = {
      'default' => {
        'bundler' => 'esbuild',
        'minify' => true,
        'sourcemap' => false
      }
    }

    File.write(File.join(config_dir, 'railpack.yml'), custom_config.to_yaml)

    # Test that config is loaded
    config = Railpack::Config.new.for_environment('development')
    assert_equal 'esbuild', config['bundler']
    assert_equal true, config['minify']
    assert_equal false, config['sourcemap']
  end

  def test_rails_asset_manifest_generation_integration
    # Test full integration of manifest generation with Rails-like setup
    rails_mock = Module.new
    rails_mock.define_singleton_method(:version) { '7.0.0' }
    rails_mock.define_singleton_method(:root) { Pathname.new(@temp_dir) }
    Object.const_set(:Rails, rails_mock)

    Object.const_set(:Propshaft, Module.new)

    # Create Rails-like build directory
    builds_dir = File.join(@temp_dir, 'app/assets/builds')
    FileUtils.mkdir_p(builds_dir)

    # Create assets like Rails would
    File.write(File.join(builds_dir, 'application.js'), '// Rails application.js')
    File.write(File.join(builds_dir, 'application.css'), '/* Rails application.css */')

    config = { 'outdir' => builds_dir }
    manager = Railpack::Manager.new

    # This should automatically detect Propshaft and generate manifest
    manager.send(:generate_asset_manifest, config)

    # Should have generated Propshaft manifest
    manifest_path = File.join(builds_dir, '.manifest.json')
    assert File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))
    assert manifest.key?('application.js')
    assert manifest.key?('application.css')
  ensure
    Object.send(:remove_const, :Propshaft) if defined?(Propshaft)
  end

  def test_rails_sprockets_manifest_generation_integration
    # Mock Rails with Sprockets properly for full integration test
    rails_mock = Module.new
    rails_mock.define_singleton_method(:version) { '6.1.0' }
    rails_mock.define_singleton_method(:root) { Pathname.new(@temp_dir) }

    # Mock Rails application with assets config that behaves like Sprockets (not Propshaft)
    app_mock = Object.new
    def app_mock.config
      @config ||= Object.new.tap do |config|
        def config.assets
          @assets ||= Object.new.tap do |assets|
            def assets.is_a?(klass)
              # Return false for Propshaft::Assembler (simulating Sprockets environment)
              false
            end
          end
        end
      end
    end

    rails_mock.define_singleton_method(:application) { app_mock }
    Object.const_set(:Rails, rails_mock)

    # Mock Sprockets with Manifest constant
    sprockets_mock = Module.new
    sprockets_mock.const_set(:Manifest, Class.new)
    Object.const_set(:Sprockets, sprockets_mock)

    # Create Rails-like build directory
    builds_dir = File.join(@temp_dir, 'app/assets/builds')
    FileUtils.mkdir_p(builds_dir)

    # Create assets like Rails would
    File.write(File.join(builds_dir, 'application.js'), '// Rails application.js')
    File.write(File.join(builds_dir, 'application.css'), '/* Rails application.css */')

    config = { 'outdir' => builds_dir }
    manager = Railpack::Manager.new

    # Force Sprockets detection by mocking the detection method
    manager.define_singleton_method(:detect_asset_pipeline) { :sprockets }

    # This should generate Sprockets manifest through the normal code path
    manager.send(:generate_asset_manifest, config)

    # Should have generated Sprockets manifest
    manifest_files = Dir.glob("#{builds_dir}/.sprockets-manifest-*.json")
    assert_equal 1, manifest_files.length, "Should generate exactly one Sprockets manifest file"

    manifest_path = manifest_files.first
    assert File.exist?(manifest_path), "Manifest file should exist"

    manifest = JSON.parse(File.read(manifest_path))
    assert manifest.key?('files'), "Manifest should have files section"
    assert manifest.key?('assets'), "Manifest should have assets section"

    # Check that application files are mapped
    assert manifest['assets'].key?('application.js'), "Should map application.js"
    assert manifest['assets'].key?('application.css'), "Should map application.css"

    # Check file entries exist
    assert manifest['files'].key?(manifest['assets']['application.js']), "Should have application.js file entry"
    assert manifest['files'].key?(manifest['assets']['application.css']), "Should have application.css file entry"

    # Verify file entry structure
    js_entry = manifest['files'][manifest['assets']['application.js']]
    assert js_entry.key?('logical_path'), "JS entry should have logical_path"
    assert js_entry.key?('pathname'), "JS entry should have pathname"
    assert js_entry.key?('digest'), "JS entry should have digest"
    assert js_entry.key?('size'), "JS entry should have size"
    assert js_entry.key?('mtime'), "JS entry should have mtime"
  ensure
    Object.send(:remove_const, :Sprockets) if defined?(Sprockets)
  end
end