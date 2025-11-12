# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "dry/container/stub"
require "factorix"
require "fileutils"
require "tmpdir"
require "webmock/rspec"

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each {|f| require f }

RSpec.shared_context "with testing log stream" do
  let(:log_stream) { RSpec.configuration.log_stream }

  def log_content
    log_stream.string
  end

  after do
    # Clear the log stream for the next test
    log_stream.rewind
    log_stream.truncate(0)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include_context "with testing log stream"

  # Add log_stream setting for accessing test logger output
  config.add_setting :log_stream

  # Isolate XDG directories for tests to prevent reading user's config files
  # and polluting user's cache/data/state directories
  config.before(:suite) do
    # Save original environment variables
    @original_xdg_env = {
      "XDG_CONFIG_HOME" => ENV.fetch("XDG_CONFIG_HOME", nil),
      "XDG_CACHE_HOME" => ENV.fetch("XDG_CACHE_HOME", nil),
      "XDG_DATA_HOME" => ENV.fetch("XDG_DATA_HOME", nil),
      "XDG_STATE_HOME" => ENV.fetch("XDG_STATE_HOME", nil)
    }

    # Create temporary directory for test suite
    @test_tmpdir = Dir.mktmpdir("factorix-test-")

    # Set test-specific XDG directories
    ENV["XDG_CONFIG_HOME"] = File.join(@test_tmpdir, "config")
    ENV["XDG_CACHE_HOME"] = File.join(@test_tmpdir, "cache")
    ENV["XDG_DATA_HOME"] = File.join(@test_tmpdir, "data")
    ENV["XDG_STATE_HOME"] = File.join(@test_tmpdir, "state")

    # Reset Application cache directory configuration
    runtime = Factorix::Application.resolve(:runtime)
    Factorix::Application.config.cache.download.dir = runtime.factorix_cache_dir / "download"
    Factorix::Application.config.cache.api.dir = runtime.factorix_cache_dir / "api"

    # Stub logger to examine its output and to prevent writing to system log files during tests
    Factorix::Application.enable_stubs!
    config.log_stream = StringIO.new
    Factorix::Application.stub(:logger, Dry.Logger(:test, stream: config.log_stream, template: "[%<time>s] %<severity>s: %<message>s %<payload>s"))
  end

  config.after(:suite) do
    # Restore original environment variables
    @original_xdg_env&.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end

    # Clean up temporary directory
    FileUtils.rm_rf(@test_tmpdir) if @test_tmpdir && File.exist?(@test_tmpdir)
  end
end
