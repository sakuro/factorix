# frozen_string_literal: true

require_relative "../../lib/factorix/retry_strategy"

RSpec.describe Factorix::RetryStrategy do
  describe "#initialize" do
    context "with default options" do
      subject(:strategy) { Factorix::RetryStrategy.new }

      it "sets default options" do
        expect(strategy.instance_variable_get(:@options)).to include(
          tries: 3,
          base_interval: 1.0,
          multiplier: 2.0,
          rand_factor: 0.25
        )
      end

      it "sets default retry exceptions" do
        expect(strategy.instance_variable_get(:@options)[:on]).to contain_exactly(
          Errno::ETIMEDOUT,
          Errno::ECONNRESET,
          Errno::ECONNREFUSED,
          Net::OpenTimeout,
          Net::ReadTimeout,
          SocketError,
          OpenSSL::SSL::SSLError,
          EOFError
        )
      end

      it "sets default retry callback" do
        expect(strategy.instance_variable_get(:@options)[:on_retry]).to be_a(Proc)
      end
    end

    context "with custom options" do
      subject(:strategy) { Factorix::RetryStrategy.new(**custom_options) }

      let(:custom_options) do
        {
          tries: 5,
          base_interval: 2.0,
          multiplier: 3.0,
          rand_factor: 0.5,
          on: [StandardError]
        }
      end

      it "merges custom options with defaults" do
        expect(strategy.instance_variable_get(:@options)).to include(custom_options)
      end
    end

    context "with custom retry callback" do
      subject(:strategy) { Factorix::RetryStrategy.new(on_retry: custom_callback) }

      let(:custom_callback) { ->(_exception, _try, _elapsed_time, _next_interval) {} }

      it "uses the custom callback" do
        expect(strategy.instance_variable_get(:@options)[:on_retry]).to eq(custom_callback)
      end
    end
  end

  describe "#with_retry" do
    subject(:strategy) { Factorix::RetryStrategy.new(tries: 3, base_interval: 0) }

    context "when the block succeeds" do
      it "returns the block's result" do
        result = strategy.with_retry { "success" }
        expect(result).to eq("success")
      end
    end

    context "when the block fails temporarily" do
      let(:counter) { instance_double(Struct.new(:count)) }

      before do
        call_count = 0
        allow(counter).to receive(:count) do
          call_count += 1
          if call_count == 1
            raise Errno::ETIMEDOUT, "Connection timed out"
          end

          "success"
        end
      end

      it "retries and eventually succeeds" do
        result = strategy.with_retry { counter.count }
        expect(result).to eq("success")
        expect(counter).to have_received(:count).exactly(2).times
      end
    end

    context "when the block always fails" do
      it "raises the last error" do
        expect { strategy.with_retry { raise Errno::ETIMEDOUT } }.to raise_error(Errno::ETIMEDOUT)
      end
    end

    context "when an unexpected error occurs" do
      it "does not retry" do
        expect { strategy.with_retry { raise StandardError } }.to raise_error(StandardError)
      end
    end
  end

  describe "retry callback" do
    subject(:strategy) { Factorix::RetryStrategy.new(tries: 2, base_interval: 0) }

    it "logs retry attempts" do
      expect {
        begin
          strategy.with_retry { raise Errno::ETIMEDOUT, "Connection timed out" }
        rescue Errno::ETIMEDOUT
          # Expected error
        end
      }.to output(
        /Download retry \d+ after \d+\.?\d+e?-?\d*s, next in \d+\.?\d+e?-?\d*s: Errno::ETIMEDOUT/
      ).to_stderr
    end
  end
end
