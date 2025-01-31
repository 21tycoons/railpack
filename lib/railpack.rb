# frozen_string_literal: true

require_relative "railpack/version"

module Railpack
  class Error < StandardError; end

  class Base
    # Your code goes here...
  end
end


require_relative "railpack/instance"
require_relative "railpack/configuration"
require_relative "railpack/bun_manager"
require_relative "railpack/webpack_manager"
require_relative "railpack/esbuild_manager"
require_relative "railpack/rollup_manager"
