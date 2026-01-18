# frozen_string_literal: true

require "stringio"

module OutputHelpers
  # Capture stderr output from a block
  #
  # @yield the block to execute
  # @return [String] the captured stderr
  def capture_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end
end

RSpec.configure do |config|
  config.include OutputHelpers
end
