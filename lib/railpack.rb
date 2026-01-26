# Railpack - Multi-bundler asset pipeline for Rails
require_relative "railpack/version"
require_relative "railpack/bundler"
require_relative "railpack/bundlers/bun_bundler"
require_relative "railpack/bundlers/esbuild_bundler"
require_relative "railpack/config"
require_relative "railpack/manager"

module Railpack
  class Error < StandardError; end

  class << self
    attr_accessor :logger

    def config
      @config ||= Config.new
    end

    def manager
      @manager ||= Manager.new
    end
  end

  # Hook system for events
  def self.on_error(&block)
    @error_hooks ||= []
    @error_hooks << block
  end

  def self.on_build_start(&block)
    @build_start_hooks ||= []
    @build_start_hooks << block
  end

  def self.on_build_complete(&block)
    @build_complete_hooks ||= []
    @build_complete_hooks << block
  end

  # Trigger hooks
  def self.trigger_error(error)
    @error_hooks&.each { |hook| hook.call(error) }
  end

  def self.trigger_build_start(config)
    @build_start_hooks&.each { |hook| hook.call(config) }
  end

  def self.trigger_build_complete(result)
    @build_complete_hooks&.each { |hook| hook.call(result) }
  end

  # Delegate to manager
  def self.method_missing(method, *args, &block)
    if manager.respond_to?(method)
      manager.send(method, *args, &block)
    else
      super
    end
  end

  def self.respond_to_missing?(method, include_private = false)
    manager.respond_to?(method) || super
  end
end