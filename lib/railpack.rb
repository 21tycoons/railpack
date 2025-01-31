# frozen_string_literal: true

require_relative "railpack/version"

module Railpack
  class Error < StandardError; end

  class Base
    # Your code goes here...
  end
end


require "./railpack/instance"
require "./railpack/configuration"
require "./railpack/bun_manager"
require "./railpack/webpack_manager"
require "./railpack/esbuild_manager"
require "./railpack/rollup_manager"
