module Railpack
  class Bundler
    attr_reader :config

    def initialize(config)
      @config = config
    end

    # Common interface all bundlers must implement
    def build!(args = [])
      raise NotImplementedError, "#{self.class.name} must implement #build!"
    end

    def watch(args = [])
      raise NotImplementedError, "#{self.class.name} must implement #watch"
    end

    def install!(args = [])
      raise NotImplementedError, "#{self.class.name} must implement #install!"
    end

    def name
      self.class.name.split('::').last.sub('Bundler', '').downcase
    end

    def commands
      raise NotImplementedError, "#{self.class.name} must implement #commands"
    end

    protected

    def execute(command_array)
      system(*command_array)
    end

    def execute!(command_array)
      success = system(*command_array)
      raise Error, "Command failed: #{command_array.join(' ')}" unless success
      success
    end
  end
end