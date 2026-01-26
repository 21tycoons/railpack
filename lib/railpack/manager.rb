module Railpack
  class Manager
    BUNDLERS = {
      'bun' => BunBundler,
      'esbuild' => EsbuildBundler
    }

    def initialize
      @bundler = create_bundler
    end

    # Unified API - delegate to the selected bundler
    def build!(args = [])
      config = Railpack.config.for_environment(Rails.env)
      Railpack.trigger_build_start(config)

      begin
        result = @bundler.build!(args)
        Railpack.trigger_build_complete({ success: true, config: config })
        result
      rescue => error
        Railpack.trigger_error(error)
        Railpack.trigger_build_complete({ success: false, error: error, config: config })
        raise
      end
    end

    def watch(args = [])
      @bundler.watch(args)
    end

    def install!(args = [])
      @bundler.install!(args)
    end

    def add(*packages)
      @bundler.add(*packages)
    end

    def remove(*packages)
      @bundler.remove(*packages)
    end

    def exec(*args)
      @bundler.exec(*args)
    end

    def version
      @bundler.version
    end

    def installed?
      @bundler.installed?
    end

    # Rails asset pipeline integration
    def self.enhance_assets_precompile(*tasks)
      if defined?(Rake::Task) && Rake::Task.task_defined?("assets:precompile")
        Rake::Task["assets:precompile"].enhance(tasks)
      end
    end

    # Alias for convenience
    singleton_class.alias_method :enhance, :enhance_assets_precompile

    private

    def create_bundler
      bundler_name = Railpack.config.bundler
      bundler_class = BUNDLERS[bundler_name]

      unless bundler_class
        raise Error, "Unsupported bundler: #{bundler_name}. Available: #{BUNDLERS.keys.join(', ')}"
      end

      bundler_class.new(Railpack.config)
    end
  end
end