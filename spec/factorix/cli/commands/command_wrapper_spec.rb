# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::CommandWrapper do
  let(:runtime) do
    instance_double(
      Factorix::Runtime::Base,
      factorix_config_path: Pathname("/tmp/factorix/config.toml"),
      running?: false
    )
  end

  let(:logger) { instance_double(Factorix::Logger) }
  let(:default_config_path) { Pathname("/tmp/factorix/config.toml") }

  before do
    # Define test command class with stub_const for automatic cleanup
    test_class = Class.new(Factorix::CLI::Commands::Base) do
      def call(**)
        say "executed", prefix: :success
      end
    end
    stub_const("TestCommand", test_class)

    allow(Factorix.app).to receive_messages(runtime:, logger:)
    allow(Factorix).to receive(:load_config)
    allow(runtime).to receive(:factorix_config_path).and_return(default_config_path)
    allow(default_config_path).to receive(:exist?).and_return(false)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("FACTORIX_CONFIG").and_return(nil)
  end

  describe "#call" do
    it "suppresses output when --quiet is passed" do
      result = run_command(TestCommand, %w[--quiet])
      expect(result.stdout).to be_empty
    end

    it "calls the command's implementation via super" do
      result = run_command(TestCommand)
      expect(result.stdout).to include("executed")
    end

    context "with config_path option" do
      it "loads configuration from specified path" do
        run_command(TestCommand, %w[--config-path=/custom/config.toml])
        expect(Factorix).to have_received(:load_config).with(Pathname("/custom/config.toml"))
      end
    end

    context "without config_path option" do
      context "when FACTORIX_CONFIG environment variable is set" do
        let(:config_file) { Tempfile.new(["config", ".rb"]) }

        after do
          config_file.close
          config_file.unlink
        end

        it "loads configuration from environment variable path" do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:[]).with("FACTORIX_CONFIG").and_return(config_file.path)
          allow(ENV).to receive(:fetch).with("FACTORIX_CONFIG").and_return(config_file.path)

          run_command(TestCommand)

          expect(Factorix).to have_received(:load_config) do |path|
            expect(path).to be_a(Pathname)
            expect(path.to_s).to eq(config_file.path)
          end
        end
      end

      context "when FACTORIX_CONFIG is not set" do
        it "delegates default-path resolution to Factorix.load_config" do
          run_command(TestCommand)
          expect(Factorix).to have_received(:load_config).with(no_args)
        end
      end
    end

    context "with log_level option" do
      before do
        allow(logger).to receive(:level=)
      end

      %w[debug info warn error fatal].each do |level|
        it "sets the logger level to :#{level}" do
          run_command(TestCommand, %W[--log-level=#{level}])
          expect(logger).to have_received(:level=).with(level.to_sym)
        end
      end
    end

    context "without log_level option" do
      it "does not change log level" do
        allow(logger).to receive(:level=)
        run_command(TestCommand)
        expect(logger).not_to have_received(:level=)
      end
    end
  end
end
