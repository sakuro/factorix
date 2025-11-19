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
