# Changelog

## [1.2.16] - 2026-01-26

### 🚀 **Manager Class Refactoring - Production-Ready Architecture**

This release includes a comprehensive refactoring of the `Railpack::Manager` class, transforming it from a monolithic orchestrator into a clean, maintainable, and extensible system.

#### ✨ **Architecture Improvements**
- **Extracted Manifest Generation**: Created dedicated `Railpack::Manifest::Propshaft` and `Railpack::Manifest::Sprockets` classes for asset manifest generation
- **Improved Pipeline Detection**: Direct inspection of `Rails.application.config.assets` class for more reliable asset pipeline detection
- **Enhanced Bundle Size Reporting**: Human-readable bundle sizes (B, KB, MB, GB) instead of raw bytes

#### 🛡️ **Code Quality & Maintainability**
- **Reduced Manager Complexity**: Manager class reduced by ~35% (280 → 180 lines)
- **Separation of Concerns**: Manifest generation isolated from orchestration logic
- **Comprehensive Documentation**: Added class-level and method-level documentation
- **Future-Proof Design**: Easy to add new manifest formats or deprecate old ones

#### 📊 **Developer Experience**
- **Better Error Handling**: Improved error logging with backtrace context
- **Enhanced Logging**: More informative build completion messages
- **Thread Safety**: Maintained thread-safe operations throughout refactoring

#### 🔧 **Technical Details**
- **Manifest Classes**: `Railpack::Manifest::Propshaft` and `Railpack::Manifest::Sprockets` with proper JSON formatting
- **Pipeline Detection**: Direct Rails config inspection with version-based fallback
- **Bundle Size**: Human-readable formatting with automatic unit scaling
- **Backward Compatibility**: Zero breaking changes - all existing APIs preserved

#### 📚 **Benefits**
- **Testability**: Manifest logic now isolated and independently testable
- **Extensibility**: Trivial to add support for new asset pipelines (Vite, Webpack 5, etc.)
- **Maintainability**: Smaller, focused classes with single responsibilities
- **Performance**: Maintained fast manifest generation and bundle analysis

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