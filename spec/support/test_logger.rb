# frozen_string_literal: true

require "dry/logger"
require "stringio"

# Stub logger to prevent writing to system log files during tests
# and provide access to log output for verification

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
  config.add_setting :log_stream

  config.before(:suite) do
    config.log_stream = StringIO.new
    Factorix::Application.stub(:logger, Dry.Logger(:test, stream: config.log_stream, template: "[%<time>s] %<severity>s: %<message>s %<payload>s"))
  end

  config.include_context "with testing log stream"
end
