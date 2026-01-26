# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'json'
require 'railpack'

class SprocketsTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_sprockets_manifest_generation_basic
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create fake built assets
    File.write(File.join(outdir, 'application.js'), 'console.log("app");')
    File.write(File.join(outdir, 'application.css'), 'body { color: blue; }')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    # Force Sprockets detection
    def manager.detect_asset_pipeline
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    # Find the generated manifest file
    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    assert_equal 1, manifest_files.size

    manifest_path = manifest_files.first
    assert File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))

    # Check Sprockets manifest structure
    assert manifest.key?('files')
    assert manifest.key?('assets')

    # Check assets mapping
    assert manifest['assets'].key?('application.js')
    assert manifest['assets'].key?('application.css')

    # Check file entries exist
    js_digest_key = manifest['assets']['application.js']
    css_digest_key = manifest['assets']['application.css']

    assert manifest['files'].key?(js_digest_key)
    assert manifest['files'].key?(css_digest_key)
  end

  def test_sprockets_manifest_generation_file_structure
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    content = 'console.log("test");'
    File.write(File.join(outdir, 'application.js'), content)

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    manifest = JSON.parse(File.read(manifest_files.first))

    digest_key = manifest['assets']['application.js']
    file_entry = manifest['files'][digest_key]

    # Check file entry structure
    assert_equal 'application.js', file_entry['logical_path']
    assert_equal 'application.js', file_entry['pathname']
    assert_equal Digest::MD5.hexdigest(content), file_entry['digest']
    assert_equal File.size(File.join(outdir, 'application.js')), file_entry['size']
    assert file_entry['mtime'].is_a?(String)
  end

  def test_sprockets_manifest_generation_digest_filename
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    File.write(File.join(outdir, 'application.js'), 'console.log("app");')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    manifest = JSON.parse(File.read(manifest_files.first))

    digest_key = manifest['assets']['application.js']

    # Digest key should be in format: digest-filename
    expected_digest = Digest::MD5.hexdigest('console.log("app");')
    assert digest_key.start_with?(expected_digest)
    assert digest_key.include?('-application.js')
  end

  def test_sprockets_manifest_generation_multiple_assets
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
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    manifest = JSON.parse(File.read(manifest_files.first))

    # Check application assets are in the assets mapping
    assert manifest['assets'].key?('application.js')
    assert manifest['assets'].key?('application.css')

    # Check all assets are in the files
    assets.each do |filename, content|
      # Find the file entry by checking all files
      found = false
      manifest['files'].each do |digest_key, file_entry|
        if file_entry['logical_path'] == filename
          found = true
          assert_equal Digest::MD5.hexdigest(content), file_entry['digest']
          break
        end
      end
      assert found, "Asset #{filename} not found in manifest files"
    end
  end

  def test_sprockets_manifest_generation_empty_directory
    outdir = File.join(@temp_dir, 'empty_builds')
    FileUtils.mkdir_p(outdir)

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    assert_equal 1, manifest_files.size

    manifest = JSON.parse(File.read(manifest_files.first))

    # Empty directory should have empty manifest
    assert_empty manifest['files']
    assert_empty manifest['assets']
  end

  def test_sprockets_manifest_generation_with_subdirectories
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
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    manifest = JSON.parse(File.read(manifest_files.first))

    # Should find assets in subdirectories
    assert manifest['assets'].key?('application.js')
    assert manifest['assets'].key?('application.css')

    # Check paths include subdirectories
    js_digest_key = manifest['assets']['application.js']
    css_digest_key = manifest['assets']['application.css']

    assert manifest['files'][js_digest_key]['pathname'].include?('javascripts/application.js')
    assert manifest['files'][css_digest_key]['pathname'].include?('stylesheets/application.css')
  end

  def test_sprockets_manifest_filename_uniqueness
    outdir1 = File.join(@temp_dir, 'builds1')
    outdir2 = File.join(@temp_dir, 'builds2')
    FileUtils.mkdir_p([outdir1, outdir2])

    # Create same assets in different directories
    File.write(File.join(outdir1, 'application.js'), 'console.log("app");')
    File.write(File.join(outdir2, 'application.js'), 'console.log("app");')

    # Generate manifests
    [outdir1, outdir2].each do |outdir|
      config = { 'outdir' => outdir }
      manager = Railpack::Manager.new

      def manager.detect_asset_pipeline
        :sprockets
      end

      manager.send(:generate_asset_manifest, config)
    end

    # Manifest filenames should be different (based on directory path digest)
    manifest_files1 = Dir.glob("#{outdir1}/.sprockets-manifest-*.json")
    manifest_files2 = Dir.glob("#{outdir2}/.sprockets-manifest-*.json")

    assert_equal 1, manifest_files1.size
    assert_equal 1, manifest_files2.size

    # Filenames should be different
    refute_equal File.basename(manifest_files1.first), File.basename(manifest_files2.first)
  end

  def test_sprockets_manifest_excludes_source_maps
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    # Create JS with source map
    File.write(File.join(outdir, 'application.js'), 'console.log("app");')
    File.write(File.join(outdir, 'application.js.map'), '{"version":3,"sources":[]}')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    manifest = JSON.parse(File.read(manifest_files.first))

    # Source maps should not be included in assets
    assert manifest['assets'].key?('application.js')
    refute manifest['assets'].key?('application.js.map')
  end

  def test_sprockets_manifest_mtime_format
    outdir = File.join(@temp_dir, 'builds')
    FileUtils.mkdir_p(outdir)

    file_path = File.join(outdir, 'application.js')
    File.write(file_path, 'console.log("app");')

    config = { 'outdir' => outdir }
    manager = Railpack::Manager.new

    def manager.detect_asset_pipeline
      :sprockets
    end

    manager.send(:generate_asset_manifest, config)

    manifest_files = Dir.glob("#{outdir}/.sprockets-manifest-*.json")
    manifest = JSON.parse(File.read(manifest_files.first))

    digest_key = manifest['assets']['application.js']
    mtime_str = manifest['files'][digest_key]['mtime']

    # Should be ISO8601 format
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, mtime_str)

    # Should match actual file mtime
    expected_mtime = File.mtime(file_path).iso8601
    assert_equal expected_mtime, mtime_str
  end
end