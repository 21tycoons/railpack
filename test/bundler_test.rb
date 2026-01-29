# frozen_string_literal: true

require 'minitest/autorun'
require 'railpack'

class BundlerTest < Minitest::Test
  def test_bundler_base_class
    bundler = Railpack::Bundler.new({})

    assert_respond_to bundler, :build!
    assert_respond_to bundler, :watch
    assert_respond_to bundler, :install!
    assert_respond_to bundler, :name
    assert_respond_to bundler, :commands
  end

  def test_bun_bundler_initialization
    bundler = Railpack::BunBundler.new({})
    assert_instance_of Railpack::BunBundler, bundler
    assert_equal 'bun', bundler.name
  end

  def test_bun_bundler_commands
    bundler = Railpack::BunBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'bun run build', commands[:build]
    assert_equal 'bun run watch', commands[:watch]
    assert_equal 'bun install', commands[:install]
  end

  def test_esbuild_bundler_initialization
    bundler = Railpack::EsbuildBundler.new({})
    assert_instance_of Railpack::EsbuildBundler, bundler
    assert_equal 'esbuild', bundler.name
  end

  def test_esbuild_bundler_commands
    bundler = Railpack::EsbuildBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'esbuild', commands[:build]
    assert_equal 'esbuild', commands[:watch]
    assert_equal 'npm install', commands[:install]
  end

  def test_rollup_bundler_initialization
    bundler = Railpack::RollupBundler.new({})
    assert_instance_of Railpack::RollupBundler, bundler
    assert_equal 'rollup', bundler.name
  end

  def test_rollup_bundler_commands
    bundler = Railpack::RollupBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'rollup', commands[:build]
    assert_equal 'rollup --watch', commands[:watch]
    assert_equal 'npm install', commands[:install]
  end

  def test_webpack_bundler_initialization
    bundler = Railpack::WebpackBundler.new({})
    assert_instance_of Railpack::WebpackBundler, bundler
    assert_equal 'webpack', bundler.name
  end

  def test_webpack_bundler_commands
    bundler = Railpack::WebpackBundler.new({})
    commands = bundler.send(:commands)

    assert_equal 'webpack', commands[:build]
    assert_equal 'webpack --watch', commands[:watch]
    assert_equal 'npm install', commands[:install]
  end

  def test_bundler_name_uniqueness
    bundlers = [
      Railpack::BunBundler.new({}),
      Railpack::EsbuildBundler.new({}),
      Railpack::RollupBundler.new({}),
      Railpack::WebpackBundler.new({})
    ]

    names = bundlers.map(&:name)
    assert_equal names.uniq.size, names.size, "All bundler names should be unique"
  end

  def test_bundler_commands_structure
    bundlers = [
      Railpack::BunBundler.new({}),
      Railpack::EsbuildBundler.new({}),
      Railpack::RollupBundler.new({}),
      Railpack::WebpackBundler.new({})
    ]

    bundlers.each do |bundler|
      commands = bundler.send(:commands)
      assert_respond_to commands, :[]
      assert commands.key?(:build)
      assert commands.key?(:watch)
      assert commands.key?(:install)

      # All commands should be strings
      assert commands[:build].is_a?(String)
      assert commands[:watch].is_a?(String)
      assert commands[:install].is_a?(String)
    end
  end

  def test_bundler_inheritance
    bundlers = [
      Railpack::BunBundler,
      Railpack::EsbuildBundler,
      Railpack::RollupBundler,
      Railpack::WebpackBundler
    ]

    bundlers.each do |bundler_class|
      assert bundler_class < Railpack::Bundler, "#{bundler_class} should inherit from Railpack::Bundler"
    end
  end

  def test_bundler_config_passing
    config = { 'target' => 'node', 'format' => 'cjs' }

    bundler = Railpack::BunBundler.new(config)
    assert_equal config, bundler.instance_variable_get(:@config)
  end

  def test_bundler_error_handling
    bundler = Railpack::BunBundler.new({})

    # Mock system to return false (command failure)
    bundler.define_singleton_method(:execute!) do |*args|
      raise Railpack::Error, "Command failed"
    end

    # This should raise an error
    assert_raises(Railpack::Error) do
      bundler.build!([])
    end
  end

  def test_bundler_watch_method
    bundler = Railpack::BunBundler.new({})

    # Mock system to avoid actual execution
    bundler.define_singleton_method(:system) do |*args|
      true
    end

    # Watch should not raise an error
    begin
      bundler.watch([])
      assert true # If we get here, no exception was raised
    rescue
      flunk "watch method should not raise an error"
    end
  end

  def test_bundler_install_method
    bundler = Railpack::BunBundler.new({})

    # Mock system to return true (command success)
    bundler.define_singleton_method(:system) do |*args|
      true
    end

    result = bundler.install!
    assert result
  end
end