module Railpack
  class EsbuildBundler < NpmBasedBundler
    def base_command
      "esbuild"
    end

    def default_commands
      {
        build: base_command,
        watch: base_command,
        install: "#{package_manager} install",
        version: "#{base_command} --version"
      }
    end

    def build!(args = [])
      full_args = build_command_args(:build, args)
      execute(full_args)
    end

    def watch(args = [])
      full_args = build_command_args(:watch, args)
      execute(full_args)
    end
  end
end
