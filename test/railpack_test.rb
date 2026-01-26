# frozen_string_literal: true

require 'minitest/autorun'
require 'railpack'

class RailpackTest < Minitest::Test
  def test_version
    refute_nil ::Railpack::VERSION
  end

  def test_config
    assert_instance_of Railpack::Config, Railpack.config
  end

  def test_manager
    assert_instance_of Railpack::Manager, Railpack.manager
  end

  def test_bundler_support
    assert_includes Railpack::Manager::BUNDLERS.keys, 'bun'
    assert_includes Railpack::Manager::BUNDLERS.keys, 'esbuild'
    assert_equal Railpack::BunBundler, Railpack::Manager::BUNDLERS['bun']
    assert_equal Railpack::EsbuildBundler, Railpack::Manager::BUNDLERS['esbuild']
  end
end
