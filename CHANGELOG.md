# Changelog

## [1.2.15] - 2026-01-26

### 🚀 **Major Config Class Refactor - Production-Ready Security & Validation**

This release includes a comprehensive overhaul of the `Railpack::Config` class, transforming it from a basic configuration system into a production-ready, secure, and developer-friendly solution.

#### ✨ **Security Enhancements**
- **YAML Safe Loading**: Implemented `permitted_classes: [], aliases: false` to prevent YAML deserialization attacks
- **Deep Immutability**: All configs are now deep-frozen to prevent runtime mutations
- **Zero Runtime Changes**: Removed setter methods - configs are immutable after loading

#### 🛡️ **Production Validation**
- **Critical Settings Validation**: Production environment validates `outdir` and `bundler` are specified
- **Bundler Validation**: Warns about unknown bundlers with helpful suggestions
- **Configurable Strict Mode**: `RAILPACK_STRICT=1` env var enables strict mode (raises errors instead of warnings)

#### 📝 **Developer Experience**
- **Explicit Accessors**: Added explicit accessor methods for all known config keys
- **Comprehensive Documentation**: Class-level docs with examples and architecture explanation
- **Deprecation Warnings**: Future-proofing with deprecation warnings for `method_missing` usage (v2.0 preparation)
- **Logger Integration**: Uses `Railpack.logger` for consistent logging (defaults to Rails.logger)

#### ⚡ **Performance & Reliability**
- **Cached Configurations**: Merged configs are cached per environment for better performance
- **Development Reload**: Added `reload!` method for config hot-reloading during development
- **Thread Safety**: Immutable configs ensure thread-safe access

#### 🔧 **Breaking Changes (Minimal)**
- Configs are now immutable - no runtime mutations allowed
- Must set config values in `config/railpack.yml` only

#### 📚 **Migration Guide**
```ruby
# Before (still works with deprecation warning)
config.unknown_key  # method_missing fallback

# After (recommended)
config.unknown_key  # Use explicit accessors or config hash
```

## [1.2.14] - 2026-01-26

### ✨ **Future-Proofing with Deprecation Warnings**
- Added deprecation warnings for dynamic config access via `method_missing`
- Prepares for v2.0 where dynamic access will be removed
- Warnings only appear when Rails.logger is available

## [1.2.13] - 2026-01-26

### 🛡️ **Production-Ready Config Validation**
- Added production environment validation for critical settings
- Enhanced bundler validation with helpful error messages
- Added comprehensive class documentation
- Implemented `reload!` method for development config reloading

## [1.2.12] - 2026-01-26

### 🔒 **Security Hardening**
- Implemented deep freezing of all configuration objects
- Added YAML safe loading with security restrictions
- Enhanced validation and error handling

## [1.2.11] - 2026-01-26

### 🚀 **Initial Config Class Implementation**
- Basic YAML configuration loading
- Environment-aware config merging
- Method missing fallback for dynamic access