# frozen_string_literal: true

require "stringio"

module OutputHelpers
  # Capture stdout output from a block
  #
  # @yield the block to execute
  # @return [String] the captured stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end

RSpec.configure do |config|
  config.include OutputHelpers
end
