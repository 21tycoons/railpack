# Railpack - Multi-bundler asset pipeline for Rails
require 'logger'

require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

require_relative "railpack/version"
require_relative "railpack/hooks"
require_relative "railpack/bundler"
require_relative "railpack/bundlers/bun_bundler"
require_relative "railpack/bundlers/esbuild_bundler"
require_relative "railpack/bundlers/rollup_bundler"
require_relative "railpack/bundlers/webpack_bundler"
require_relative "railpack/config"
require_relative "railpack/manifest"
require_relative "railpack/manager"

module Railpack
  class Error < StandardError; end

  include Hooks

  class << self
    attr_writer :logger

    def logger
      @logger ||= defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger ? Rails.logger : Logger.new($stdout)
    end

    def config
      @config ||= Config.new
    end

    def manager
      @manager ||= Manager.new
    end


  end

  # Delegate to manager
  def self.method_missing(method, *args, &block)
    if singleton_class.method_defined?(method) || private_method_defined?(method)
      send(method, *args, &block)
    elsif manager.respond_to?(method)
      manager.send(method, *args, &block)
    else
      super
    end
  end

  def self.respond_to_missing?(method, include_private = false)
    singleton_class.method_defined?(method) ||
    private_method_defined?(method) ||
    manager.respond_to?(method) ||
    super
  end
end
