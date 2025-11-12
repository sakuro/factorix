# frozen_string_literal: true

RSpec.describe Factorix::Transfer::RetryStrategy, warn: :silence do
  describe "#with_retry" do
    it "executes the block successfully without retry" do
      strategy = Factorix::Transfer::RetryStrategy.new
      result = strategy.with_retry { "success" }
      expect(result).to eq("success")
    end

    it "retries on network errors" do
      strategy = Factorix::Transfer::RetryStrategy.new(tries: 3)
      attempt = 0

      result = strategy.with_retry {
        attempt += 1
        raise Errno::ECONNRESET if attempt < 3

        "success"
      }

      expect(result).to eq("success")
      expect(attempt).to eq(3)
    end

    it "logs warnings on retry" do
      strategy = Factorix::Transfer::RetryStrategy.new(tries: 3)
      attempt = 0

      logger_spy = instance_double(Logger, warn: nil)
      allow(strategy).to receive(:logger).and_return(logger_spy)

      strategy.with_retry do
        attempt += 1
        raise Errno::ECONNRESET if attempt < 3

        "success"
      end

      expect(logger_spy).to have_received(:warn).with(/Retry.*Errno::ECONNRESET/).twice
    end

    it "retries on timeout errors" do
      strategy = Factorix::Transfer::RetryStrategy.new(tries: 2)
      attempt = 0

      result = strategy.with_retry {
        attempt += 1
        raise Net::ReadTimeout if attempt < 2

        "success"
      }

      expect(result).to eq("success")
      expect(attempt).to eq(2)
    end

    it "raises the error after all retries are exhausted" do
      strategy = Factorix::Transfer::RetryStrategy.new(tries: 2)

      expect {
        strategy.with_retry do
          raise Errno::ECONNRESET, "Connection reset"
        end
      }.to raise_error(Errno::ECONNRESET, /Connection reset/)
    end

    it "does not retry on non-retryable errors" do
      strategy = Factorix::Transfer::RetryStrategy.new
      attempt = 0

      expect {
        strategy.with_retry do
          attempt += 1
          raise ArgumentError, "Invalid argument"
        end
      }.to raise_error(ArgumentError, "Invalid argument")

      expect(attempt).to eq(1)
    end

    it "calls on_retry callback on each retry" do
      callback_calls = []
      strategy = Factorix::Transfer::RetryStrategy.new(
        tries: 3,
        on_retry: ->(exception, try, _elapsed_time, _next_interval) do
          callback_calls << {try:, exception: exception.class}
        end
      )

      attempt = 0
      strategy.with_retry do
        attempt += 1
        raise Net::ReadTimeout if attempt < 3

        "success"
      end

      expect(callback_calls.size).to eq(2)
      expect(callback_calls[0][:try]).to eq(1)
      expect(callback_calls[0][:exception]).to eq(Net::ReadTimeout)
      expect(callback_calls[1][:try]).to eq(2)
      expect(callback_calls[1][:exception]).to eq(Net::ReadTimeout)
    end

    it "uses exponential backoff with randomization" do
      strategy = Factorix::Transfer::RetryStrategy.new(
        tries: 3,
        base_interval: 1.0,
        multiplier: 2.0
      )

      # This test just ensures the strategy is configured correctly
      # Actual backoff timing is tested by the retriable gem
      attempt = 0
      strategy.with_retry do
        attempt += 1
        raise Errno::ETIMEDOUT if attempt < 3

        "success"
      end

      expect(attempt).to eq(3)
    end
  end
end
