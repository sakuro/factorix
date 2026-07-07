# frozen_string_literal: true

require "logger"

module Factorix
  # Application logger wrapping stdlib Logger
  #
  # Preserves the structured-payload call style used throughout the codebase
  # (logger.debug("message", key: value)); the payload is rendered as
  # key=value pairs. Exceptions are logged with their class and backtrace.
  class Logger
    # @param stream [Pathname, IO] log file path or IO stream
    # @param level [Symbol] initial log level (:debug, :info, :warn, :error, :fatal)
    def initialize(stream, level: :info)
      stream = stream.to_s if stream.is_a?(Pathname)
      @logger = ::Logger.new(stream)
      @logger.formatter = method(:format_entry)
      self.level = level
    end

    # Set the log level
    #
    # @param level [Symbol] log level (:debug, :info, :warn, :error, :fatal)
    # @return [void]
    def level=(level)
      @logger.level = ::Logger.const_get(level.to_s.upcase)
    end

    # @!method debug(message, **payload)
    #   Log at DEBUG level
    #   @param message [String, Exception] message or exception
    #   @param payload [Hash] structured payload rendered as key=value pairs
    #   @return [void]
    # @!method info(message, **payload)
    #   Log at INFO level (see #debug)
    # @!method warn(message, **payload)
    #   Log at WARN level (see #debug)
    # @!method error(message, **payload)
    #   Log at ERROR level (see #debug)
    # @!method fatal(message, **payload)
    #   Log at FATAL level (see #debug)
    %i[debug info warn error fatal].each do |severity|
      define_method(severity) do |message, **payload|
        @logger.public_send(severity) { render(message, payload) }
      end
    end

    private def render(message, payload)
      text = message.is_a?(Exception) ? render_exception(message) : message.to_s
      return text if payload.empty?

      "#{text} #{payload.map {|key, value| "#{key}=#{value.inspect}" }.join(" ")}"
    end

    private def render_exception(exception)
      lines = ["#{exception.class}: #{exception.message}"]
      lines.concat(exception.backtrace) if exception.backtrace
      lines.join("\n")
    end

    private def format_entry(severity, time, _progname, message)
      "[#{time.strftime("%Y-%m-%d %H:%M:%S %z")}] #{severity}: #{message}\n"
    end
  end
end
