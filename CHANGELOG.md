## [Unreleased]

## [1.2.3] - 2026-01-26

- Add install scaffold generator (`rails railpack:install`)
- Create default `config/railpack.yml` with sensible Rails defaults
- Add `rails railpack:install:force` for overwriting existing config
- Update README with install instructions
- Similar to jsbundling install experience

## [1.2.2] - 2026-01-26

- Fix asset manifest generation for Propshaft compatibility
- Generate `.manifest.json` instead of Sprockets format
- Update manifest structure with `logical_path`, `pathname`, `digest`
- Rails 7+ Propshaft compatibility

## [1.2.1] - 2026-01-26

- Add comprehensive build performance monitoring
- Implement Propshaft-compatible asset manifest generation
- Enhanced logging with emojis and structured output
- Production-ready defaults (no sourcemaps, bundle analysis off)
- Better error handling and user feedback

## [1.2.0] - 2026-01-26

- Add Webpack bundler support
- Implement WebpackBundler class with full command support
- Register webpack in Manager::BUNDLERS
- Add webpack config defaults (mode, target)
- Update tests to include webpack bundler

## [1.1.0] - 2026-01-26

- Add Rollup bundler support
- Implement RollupBundler class with tree-shaking capabilities
- Register rollup in Manager::BUNDLERS
- Add rollup config defaults (format, sourcemap)
- Update tests to include rollup bundler

## [1.0.0] - 2026-01-26

- Initial release with Bun and esbuild support
- Unified API for multiple bundlers
- Rails asset pipeline integration
- Configuration system with YAML support
- Event hooks for build lifecycle
- Rake tasks for Rails integration
- Comprehensive test suite
