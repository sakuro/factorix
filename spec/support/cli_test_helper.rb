# frozen_string_literal: true

require "stringio"

# Helper module for testing CLI commands using dry-cli 1.4.0's out:/err: feature
module CLITestHelper
  # Result object containing captured stdout, stderr, and optional exception
  CLIResult = Data.define(:stdout, :stderr, :exception) {
    def success? = exception.nil?
  }

  # Run a CLI command with captured output
  #
  # @param command_or_class [Dry::CLI::Command, Class] command instance or class
  # @param args [Array<String>] positional arguments
  # @param kwargs [Hash] keyword arguments (converted to CLI options)
  # @return [CLIResult] captured stdout, stderr, and any raised exception
  # @raise [Exception] re-raises the exception after capturing output (unless rescue_exception: true)
  def run_command(command_or_class, *args, rescue_exception: false, **kwargs)
    stdout = StringIO.new
    stderr = StringIO.new
    arguments = build_arguments(args, kwargs)
    exception = nil

    begin
      Dry.CLI(command_or_class).call(arguments:, out: stdout, err: stderr)
    rescue => e
      exception = e
      raise unless rescue_exception
    end

    CLIResult.new(stdout.string, stderr.string, exception)
  end

  private def build_arguments(args, kwargs)
    result = args.map(&:to_s)
    kwargs.each do |key, value|
      case value
      when true then result << "--#{key.to_s.tr("_", "-")}"
      when false then next
      else result << "--#{key.to_s.tr("_", "-")}=#{value}"
      end
    end
    result
  end
end

RSpec.configure do |config|
  config.include CLITestHelper
end
