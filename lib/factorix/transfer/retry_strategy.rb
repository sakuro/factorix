# frozen_string_literal: true

require "net/protocol"
require "openssl"
require "retriable"

module Factorix
  module Transfer
    # Class that manages retry strategy with exponential backoff and randomization
    class RetryStrategy
      DEFAULT_OPTIONS = {
        tries: 3,                 # Number of attempts (including the initial try)
        base_interval: 1.0,       # Start with 1 second
        multiplier: 2.0,          # Double the interval each time
        rand_factor: 0.25,        # Add randomization
        on: [                     # Exceptions to retry on
          Errno::ETIMEDOUT,
          Errno::ECONNRESET,
          Errno::ECONNREFUSED,
          Net::OpenTimeout,
          Net::ReadTimeout,
          SocketError,
          OpenSSL::SSL::SSLError,
          EOFError
        ]
      }.freeze
      private_constant :DEFAULT_OPTIONS

      # Initialize a new retry strategy with customizable options
      #
      # @param options [Hash] Options for retry behavior
      # @option options [Integer] :tries Number of attempts (including the initial try)
      # @option options [Float] :base_interval Initial interval between retries (seconds)
      # @option options [Float] :multiplier Exponential backoff multiplier
      # @option options [Float] :rand_factor Randomization factor
      # @option options [Array<Class>] :on Exception classes to retry on
      # @option options [Proc] :on_retry Callback called on each retry
      def initialize(**options)
        @options = configure_options(options)
      end

      # Execute the block with automatic retry on specified exceptions.
      # Uses exponential backoff with randomization for retry intervals
      #
      # @yield Block to execute
      # @return [Object] Return value of the block
      # @raise [StandardError] If the block fails after all retries
      def with_retry(&)
        Retriable.retriable(**@options, &)
      end

      # Configure retry options by merging with defaults and setting up callbacks
      #
      # @param options [Hash] User-provided options to merge with defaults
      # @return [Hash] Complete set of configured options
      private def configure_options(options)
        result = DEFAULT_OPTIONS.merge(options)
        unless result.key?(:on_retry)
          result[:on_retry] = method(:default_retry_callback).to_proc
        end
        result
      end

      # Default callback for retry attempts that logs retry information
      #
      # @param exception [StandardError] The exception that triggered the retry
      # @param try [Integer] The current retry attempt number
      # @param elapsed_time [Float] Time elapsed since first attempt
      # @param next_interval [Float] Time until next retry attempt
      # @return [void]
      #
      # @note Future improvement: Use Import["logger"] for structured logging
      #   instead of warn. This will allow consistent logging across the application.
      private def default_retry_callback(exception, try, elapsed_time, next_interval)
        warn "Retry #{try} after #{elapsed_time}s, next in #{next_interval}s: #{exception.class} - #{exception.message}"
      end
    end
  end
end
