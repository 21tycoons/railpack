module Railpack
  class BunBundler < Bundler
    def base_command
      @base_command ||= detect_bun_path || "bun"
    end

    def default_commands
      has_build_script = package_json_has_script?('build')
      has_watch_script = package_json_has_script?('watch')

      {
        build: has_build_script ? "run build" : "build",
        watch: has_watch_script ? "run watch" : "build --watch",
        install: "install",
        add: "add",
        remove: "remove",
        exec: "",
        version: "--version"
      }
    end

    def execute(command_array)
      system(base_command, *command_array)
    end

    def install!(args = [])
      execute([commands[:install], *args])
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
      `#{base_command} #{commands[:version]}`.strip
    end

    def installed?
      system("#{base_command} #{commands[:version]} > /dev/null 2>&1")
    end

    def build!(args = [])
      full_args = build_command_args(:build, args)
      execute([commands[:build], *full_args])
    end

    def watch(args = [])
      full_args = build_command_args(:watch, args)
      execute([commands[:watch], *full_args])
    end

    private

      def detect_bun_path
        possible_paths = [
          File.expand_path("~/.bun/bin/bun"),
          "/usr/local/bin/bun",
          "/opt/homebrew/bin/bun",
          "/home/linuxbrew/.linuxbrew/bin/bun",
          "/usr/bin/bun",
          "/bin/bun"
        ]

        possible_paths.find { |path| File.executable?(path) }
      end

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
