module Railpack
  class BunBundler < Bundler
    def commands
      {
        build: "bun run build",
        watch: "bun run watch",
        build_dev: "bun run build:development",
        clean: "bun run clean",
        install: "bun install",
        add: "bun add",
        remove: "bun remove",
        exec: "bun",
        version: "bun --version"
      }
    end

    def build!(args = [])
      execute!([commands[:build], *args])
    end

    def watch(args = [])
      execute([commands[:watch], *args])
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
  end
end