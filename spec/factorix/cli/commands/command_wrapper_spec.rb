# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::CommandWrapper do
  let(:runtime) do
    instance_double(
      Factorix::Runtime::Base,
      factorix_config_path: Pathname("/tmp/factorix/config.rb"),
      running?: false
    )
  end

  let(:logger) { instance_double(Dry::Logger::Dispatcher) }
  let(:file_backend) { instance_double(Dry::Logger::Backends::Stream, level: Logger::INFO) }
  let(:default_config_path) { Pathname("/tmp/factorix/config.rb") }

  before do
    # Define test command class with stub_const for automatic cleanup
    test_class = Class.new(Factorix::CLI::Commands::Base) do
      def call(**)
        say "executed", prefix: :success
      end
    end
    stub_const("TestCommand", test_class)

    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(runtime)
    allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
    allow(Factorix).to receive(:load_config)
    allow(logger).to receive(:backends).and_return([file_backend])
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
        context "when default config file exists" do
          before do
            allow(default_config_path).to receive(:exist?).and_return(true)
          end

          it "loads configuration from default path" do
            run_command(TestCommand)
            expect(Factorix).to have_received(:load_config).with(default_config_path)
          end
        end

        context "when default config file does not exist" do
          it "does not load configuration" do
            run_command(TestCommand)
            expect(Factorix).not_to have_received(:load_config)
          end
        end
      end
    end

    context "with log_level option" do
      before do
        allow(file_backend).to receive(:level=)
        allow(file_backend).to receive(:respond_to?).with(:level=).and_return(true)
      end

      it "sets file backend log level to DEBUG" do
        run_command(TestCommand, %w[--log-level=debug])
        expect(file_backend).to have_received(:level=).with(Logger::DEBUG)
      end

      it "sets file backend log level to INFO" do
        run_command(TestCommand, %w[--log-level=info])
        expect(file_backend).to have_received(:level=).with(Logger::INFO)
      end

      it "sets file backend log level to WARN" do
        run_command(TestCommand, %w[--log-level=warn])
        expect(file_backend).to have_received(:level=).with(Logger::WARN)
      end

      it "sets file backend log level to ERROR" do
        run_command(TestCommand, %w[--log-level=error])
        expect(file_backend).to have_received(:level=).with(Logger::ERROR)
      end

      it "sets file backend log level to FATAL" do
        run_command(TestCommand, %w[--log-level=fatal])
        expect(file_backend).to have_received(:level=).with(Logger::FATAL)
      end

      context "when file backend does not respond to level=" do
        before do
          allow(file_backend).to receive(:respond_to?).with(:level=).and_return(false)
        end

        it "does not set log level" do
          run_command(TestCommand, %w[--log-level=debug])
          expect(file_backend).not_to have_received(:level=)
        end
      end
    end

    context "without log_level option" do
      it "does not change log level" do
        allow(file_backend).to receive(:level=)
        run_command(TestCommand)
        expect(file_backend).not_to have_received(:level=)
      end
    end
  end
end
