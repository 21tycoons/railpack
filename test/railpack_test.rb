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
