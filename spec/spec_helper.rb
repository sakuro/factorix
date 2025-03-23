# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter %r{\A/spec/}
end

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter sensitive information
  config.filter_sensitive_data("<USERNAME>") { ENV.fetch("FACTORIO_USERNAME", "dummy_user") }
  config.filter_sensitive_data("<TOKEN>") { ENV.fetch("FACTORIO_TOKEN", "dummy_token") }

  # Request matching configuration
  config.default_cassette_options = {
    match_requests_on: %i[method host path]
  }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
