module Railpack
  class WebpackBundler < NpmBasedBundler
    def base_command
      "webpack"
    end

    def default_commands
      {
        build: base_command,
        watch: "#{base_command} --watch",
        install: "#{package_manager} install",
        version: "#{base_command} --version"
      }
    end

    def build!(args = [])
      full_args = build_command_args(:build, args)
      execute!([base_command, *full_args])
    end

    def watch(args = [])
      full_args = build_command_args(:watch, args)
      execute([base_command, "--watch", *full_args])
    end
  end
end
