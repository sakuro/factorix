# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "dry/configurable/test_interface"
require "dry/core"
require "dry/core/container/stub"
require "factorix"
require "fileutils"
require "tmpdir"
require "webmock/rspec"
require "zip"

# Suppress warnings about invalid dates in ZIP files
Zip.warn_invalid_date = false

WebMock.disable_net_connect!

# Enable test interfaces for dry-core container and dry-configurable
# before loading support files that may use stub
Factorix::Application.enable_stubs!
Factorix::Application.enable_test_interface

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each {|f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Isolate XDG directories for tests to prevent reading user's config files
  # and polluting user's cache/data/state directories
  config.before(:suite) do
    # Create temporary directory for test suite
    @test_tmpdir = Dir.mktmpdir("factorix-test-")

    # Set test-specific XDG directories
    ENV["XDG_CONFIG_HOME"] = File.join(@test_tmpdir, "config")
    ENV["XDG_CACHE_HOME"] = File.join(@test_tmpdir, "cache")
    ENV["XDG_DATA_HOME"] = File.join(@test_tmpdir, "data")
    ENV["XDG_STATE_HOME"] = File.join(@test_tmpdir, "state")

    # Stub runtime with new XDG directories
    new_runtime = Factorix::Runtime.detect
    Factorix::Application.stub(:runtime, new_runtime)

    # Reset configuration to defaults and reconfigure with new runtime
    Factorix::Application.reset_config
    Factorix::Application.config.cache.download.dir = new_runtime.factorix_cache_dir / "download"
    Factorix::Application.config.cache.api.dir = new_runtime.factorix_cache_dir / "api"
    Factorix::Application.config.cache.info_json.dir = new_runtime.factorix_cache_dir / "info_json"
  end

  config.after(:suite) do
    # Clean up temporary directory
    FileUtils.rm_rf(@test_tmpdir) if @test_tmpdir && File.exist?(@test_tmpdir)
  end
end
