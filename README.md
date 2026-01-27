# Railpack 🎒

**Multi-bundler asset pipeline for Rails** - Choose your bundler, unified Rails integration.

## Features

- 🚀 **Multiple Bundlers**: Bun, esbuild, Rollup, Webpack support
- 🔧 **Unified API**: Same interface regardless of bundler
- 🎯 **Rails Integration**: Seamless asset pipeline integration
- ⚡ **Hot Module Replacement**: Development server with live reload
- 🎣 **Event Hooks**: Build lifecycle callbacks
- 📦 **Production Ready**: Optimized builds for all bundlers

## Installation

Add to your Gemfile:

```ruby
gem 'railpack'
```

Then run the install generator:

```bash
rails railpack:install
```

This creates `config/railpack.yml` with sensible defaults for your Rails app.

## Configuration

Create `config/railpack.yml`:

```yaml
# Choose your bundler
bundler: bun  # or 'rollup', 'webpack', 'esbuild'

# Global defaults
default:
  target: browser
  format: esm
  minify: false
  sourcemap: false
  entrypoint: "./app/javascript/application.js"
  outdir: "app/assets/builds"
  analyze_bundle: false  # Enable for gzip size reporting

# Bundler-specific config
bun:
  target: browser
  format: esm

# Environment overrides
development:
  sourcemap: true
  analyze_bundle: true  # Show gzip sizes in dev

production:
  minify: true
  analyze_bundle: true  # Production bundle analysis
```

## Usage

### Basic Commands

```bash
# Build for production
rails railpack:build

# Watch and rebuild during development
rails railpack:watch

# Install dependencies
rails railpack:install

# Check current bundler
rails railpack:bundler
```

### Programmatic API

```ruby
# Build assets
Railpack.build!

# Watch for changes
Railpack.watch

# Install packages
Railpack.install!

# Add dependencies
Railpack.add('lodash', 'axios')
```

### Rails Integration

Railpack automatically integrates with Rails asset pipeline:

```ruby
# config/initializers/railpack.rb
require 'railpack'

# Override config at runtime
Railpack.config.sourcemap = true

# Setup logging
Railpack.logger = Rails.logger

# Build event hooks
Railpack.on_build_complete do |result|
  Rails.logger.info "Build completed: #{result[:success]}"
end
```

### Advanced Usage

#### Bundle Analysis with Gzip

Enable `analyze_bundle: true` to see both uncompressed and gzipped bundle sizes:

```yaml
# config/railpack.yml
default:
  analyze_bundle: true
```

Output example:
```
✅ Build completed successfully in 45.23ms (1.23 MB (0.45 MB gzipped))
```

#### Build Hooks with Payload Details

Hook payloads provide detailed information about build results:

```ruby
# config/initializers/railpack.rb
Railpack.on_build_complete do |payload|
  if payload[:success]
    # Success payload: { success: true, config: {...}, duration: 45.23, bundle_size: "1.23 MB" }
    Rails.logger.info "Build succeeded in #{payload[:duration]}ms - #{payload[:bundle_size]}"
  else
    # Error payload: { success: false, error: #<Error>, config: {...}, duration: 12.34 }
    Rails.logger.error "Build failed after #{payload[:duration]}ms: #{payload[:error].message}"
  end
end

Railpack.on_build_start do |config|
  # Config hash contains all current settings
  Rails.logger.info "Starting #{config['bundler']} build for #{Rails.env}"
end
```

#### Manifest Generation

Railpack automatically detects your asset pipeline and generates appropriate manifests:

```ruby
# For Propshaft (Rails 7+ default)
# Generates: app/assets/builds/.manifest.json
Railpack::Manifest::Propshaft.generate(config)

# For Sprockets (Rails < 7)
# Generates: app/assets/builds/.sprockets-manifest-*.json
Railpack::Manifest::Sprockets.generate(config)
```

The manifest generation is handled automatically after each build, but you can trigger it manually if needed.

## Supported Bundlers

### Bun (Default)
- **Fast builds** - Lightning-quick bundling
- **All-in-one** - Runtime, bundler, package manager
- **Great DX** - Excellent development experience

### Rollup
- **Tree shaking** - Optimal bundle sizes
- **Plugin ecosystem** - Extensive customization
- **ESM focus** - Modern module system

### Webpack
- **Enterprise** - Battle-tested in production
- **Feature-rich** - Extensive plugin ecosystem
- **Legacy support** - Handles all module types

### esbuild
- **Speed demon** - 10-100x faster than alternatives
- **Simple API** - Minimal configuration
- **Modern features** - ESM, minification, sourcemaps

## Switching Bundlers

Change the `bundler` setting in `config/railpack.yml`:

```yaml
bundler: esbuild  # Switch to esbuild for speed
```

Or use esbuild:

```yaml
bundler: esbuild

esbuild:
  platform: browser
  target: es2015
  minify: true
```

Railpack handles the rest - same API, different bundler under the hood.

## Development

### Adding a New Bundler

1. Create bundler class:
```ruby
# lib/railpack/bundlers/my_bundler.rb
class Railpack::MyBundler < Railpack::Bundler
  def commands
    { build: "my-build", watch: "my-watch" }
  end
  
  def build!(args = [])
    execute!([commands[:build], *args])
  end
end
```

2. Register in Manager:
```ruby
BUNDLERS = {
  'bun' => BunBundler,
  'my' => MyBundler  # Add here
}
```

## Contributing

1. Fork the repo
2. Add your bundler implementation
3. Update documentation
4. Submit a PR

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

MIT License - see LICENSE.txt

## Credits

Built by 21tycoons LLC for the Rails community.
