module Railpack
  class RollupBundler < Bundler
    def commands
      {
        build: "rollup",
        watch: "rollup --watch",
        build_dev: "rollup",
        clean: "rm -rf dist/",
        install: "npm install",
        add: "npm install",
        remove: "npm uninstall",
        exec: "node",
        version: "rollup --version"
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