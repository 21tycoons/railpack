# frozen_string_literal: true

module Railpack
  module Hooks
    extend ActiveSupport::Concern

    included do
      mattr_accessor :error_hooks, default: []
      mattr_accessor :build_start_hooks, default: []
      mattr_accessor :build_complete_hooks, default: []
    end

    class_methods do
      def on_error(&block)
        error_hooks << block
      end

      def on_build_start(&block)
        build_start_hooks << block
      end

      def on_build_complete(&block)
        build_complete_hooks << block
      end

      def trigger_error(error)
        # Report to Rails error reporter if available (Rails 7+)
        if defined?(Rails) && Rails.respond_to?(:error) && Rails.error.respond_to?(:report)
          Rails.error.report(error)
        end

        error_hooks.each { |hook| hook.call(error) }
      end

      def trigger_build_start(config)
        build_start_hooks.each { |hook| hook.call(config) }
      end

      def trigger_build_complete(result)
        build_complete_hooks.each { |hook| hook.call(result) }
      end
    end
  end
end
