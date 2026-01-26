# Railpack

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

# Bundler-specific config
bun:
  target: browser
  format: esm

# Environment overrides
development:
  sourcemap: true

production:
  minify: true
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

## License

MIT License - see LICENSE.txt

## Credits

Built by 21tycoons LLC for the Rails community.
