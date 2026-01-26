# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'json'
require 'railpack'

class PropshaftTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_propshaft_manifest_generation_basic
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create fake built assets
    File.write(File.join(outdir, 'application.js'), 'console.log("app");')
    File.write(File.join(outdir, 'application.css'), 'body { color: blue; }')
    File.write(File.join(outdir, 'vendor.js'), 'console.log("vendor");')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    # Force Propshaft detection
    def manager.detect_asset_pipeline
      :propshaft
    end

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    assert File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))

    # Check application assets
    assert manifest.key?('application.js')
    assert manifest.key?('application.css')

    # Check manifest structure
    js_entry = manifest['application.js']
    assert_equal 'application.js', js_entry['logical_path']
    assert js_entry['pathname'].end_with?('application.js')
    assert js_entry['digest']
    assert_match(/\A[a-f0-9]+\z/, js_entry['digest'])
  end

  def test_propshaft_manifest_generation_with_subdirectories
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create assets in subdirectories
    js_dir = File.join(outdir, 'javascripts')
    css_dir = File.join(outdir, 'stylesheets')
    FileUtils.mkdir_p([js_dir, css_dir])

    File.write(File.join(js_dir, 'application.js'), 'console.log("app");')
    File.write(File.join(css_dir, 'application.css'), 'body { color: blue; }')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :propshaft
    end

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    assert File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))

    # Should find assets in subdirectories with full relative paths as keys
    assert manifest.key?('javascripts/application.js')
    assert manifest.key?('stylesheets/application.css')

    # Check paths are relative
    js_entry = manifest['javascripts/application.js']
    assert_equal 'javascripts/application.js', js_entry['pathname'].to_s
    assert_equal 'javascripts/application.js', js_entry['logical_path']
  end

  def test_propshaft_manifest_generation_empty_directory
    outdir = File.join(@temp_dir, 'empty_builds')
    FileUtils.mkdir_p(outdir)

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :propshaft
    end

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    assert File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))
    assert_empty manifest
  end

  def test_propshaft_manifest_generation_digest_calculation
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    content = 'console.log("test content");'
    File.write(File.join(outdir, 'test.js'), content)

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :propshaft
    end

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    manifest = JSON.parse(File.read(manifest_path))

    # Verify digest matches file content
    expected_digest = Digest::MD5.hexdigest(content)
    assert_equal expected_digest, manifest['test.js']['digest']
  end

  def test_propshaft_manifest_generation_multiple_assets
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create multiple assets
    assets = {
      'application.js' => 'console.log("app");',
      'application.css' => 'body { color: red; }',
      'vendor.js' => 'console.log("vendor");',
      'admin.css' => '.admin { display: none; }'
    }

    assets.each do |filename, content|
      File.write(File.join(outdir, filename), content)
    end

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :propshaft
    end

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    manifest = JSON.parse(File.read(manifest_path))

    # Check all assets are included
    assert_equal assets.keys.sort, manifest.keys.sort

    # Verify each asset has correct structure
    assets.each do |filename, content|
      entry = manifest[filename]
      assert_equal filename, entry['logical_path']
      assert entry['pathname'].end_with?(filename)
      assert_equal Digest::MD5.hexdigest(content), entry['digest']
    end
  end

  def test_propshaft_manifest_generation_with_source_maps
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create JS with source map
    File.write(File.join(outdir, 'application.js'), 'console.log("app");')
    File.write(File.join(outdir, 'application.js.map'), '{"version":3,"sources":[]}')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :propshaft
    end

    manager.send(:generate_asset_manifest, config)

    manifest_path = File.join(outdir, '.manifest.json')
    manifest = JSON.parse(File.read(manifest_path))

    # Source maps should not be included in manifest
    assert manifest.key?('application.js')
    refute manifest.key?('application.js.map')
  end

  def test_propshaft_manifest_overwrites_existing
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create existing manifest
    existing_manifest = { 'old.js' => { 'logical_path' => 'old.js' } }
    manifest_path = File.join(outdir, '.manifest.json')
    File.write(manifest_path, JSON.pretty_generate(existing_manifest))

    # Create new assets
    File.write(File.join(outdir, 'application.js'), 'console.log("new");')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :propshaft
    end

    manager.send(:generate_asset_manifest, config)

    # Manifest should be overwritten
    new_manifest = JSON.parse(File.read(manifest_path))
    refute new_manifest.key?('old.js')
    assert new_manifest.key?('application.js')
  end
end