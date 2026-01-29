module Railpack
  class BunBundler < Bundler
    def base_command
      "bun"
    end

    def default_commands
      has_build_script = package_json_has_script?('build')
      has_watch_script = package_json_has_script?('watch')

      {
        build: has_build_script ? "#{base_command} run build" : "#{base_command} build",
        watch: has_watch_script ? "#{base_command} run watch" : "#{base_command} build --watch",
        install: "#{base_command} install",
        add: "#{base_command} add",
        remove: "#{base_command} remove",
        exec: base_command,
        version: "#{base_command} --version"
      }
    end

    def install!(args = [])
      execute!([commands[:install], *args])
    end

    def add(*packages)
      execute([commands[:add], *packages])
    end

    def remove(*packages)
      execute([commands[:remove], *packages])
    end

    def exec(*args)
      execute([commands[:exec], *args])
    end

    def version
      `#{commands[:version]}`.strip
    end

    def installed?
      system("#{commands[:version]} > /dev/null 2>&1")
    end

    def build!(args = [])
      full_args = build_command_args(:build, args)
      execute!([commands[:build], *full_args])
    end

    def watch(args = [])
      full_args = build_command_args(:watch, args)
      execute([commands[:watch], *full_args])
    end

    private

      def package_json_has_script?(script_name)
        return false unless File.exist?('package.json')

        begin
          package_json = JSON.parse(File.read('package.json'))
          scripts = package_json['scripts'] || {}
          scripts.key?(script_name)
        rescue JSON::ParserError
          false
        end
      end
  end
end
