# frozen_string_literal: true

require "stringio"

# Helper module for testing CLI commands using dry-cli 1.4.0's out:/err: feature
module CLITestHelper
  CLIResult = Data.define(:stdout, :stderr, :exception)

  # Result object containing captured stdout, stderr, and optional exception
  class CLIResult
    def success? = exception.nil?
  end

  # Run a CLI command with captured output
  #
  # @param command_or_class [Dry::CLI::Command, Class] command instance or class
  # @param arguments [Array<String>] CLI arguments (e.g., %w[mod-a --yes])
  # @param rescue_exception [Boolean] if true, captures exception instead of re-raising
  # @return [CLIResult] captured stdout, stderr, and any raised exception
  # @raise [Exception] re-raises the exception after capturing output (unless rescue_exception: true)
  def run_command(command_or_class, arguments=[], rescue_exception: false)
    stdout = StringIO.new
    stderr = StringIO.new
    exception = nil

    begin
      Dry.CLI(command_or_class).call(arguments:, out: stdout, err: stderr)
    rescue => e
      exception = e
      raise unless rescue_exception
    end

    CLIResult[stdout.string, stderr.string, exception]
  end
end

RSpec.configure do |config|
  config.include CLITestHelper
end
