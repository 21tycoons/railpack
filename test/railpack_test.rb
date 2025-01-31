# frozen_string_literal: true

require "test_helper"

class RailpackTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Railpack::VERSION
  end

  def test_bun_manager_exists
    assert Railpack::BunManager.new.exists?, true
  end
end
