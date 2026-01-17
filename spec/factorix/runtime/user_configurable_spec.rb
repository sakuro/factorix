# frozen_string_literal: true

RSpec.describe Factorix::Runtime::UserConfigurable do
  # Create a test runtime class with auto-detection implemented
  let(:test_runtime_class) do
    Class.new(Factorix::Runtime::Base) do
      def executable_path
        Pathname("/auto/detected/factorio")
      end

      def user_dir
        Pathname("/auto/detected/user")
      end

      def data_dir
        Pathname("/auto/detected/data")
      end
    end
  end

  # Create a test runtime class without auto-detection (raises NotImplementedError)
  let(:failing_runtime_class) { Class.new(Factorix::Runtime::Base) }

  let(:runtime) { test_runtime_class.new }
  let(:logger) { instance_double(Dry::Logger::Dispatcher) }
  let(:config) { Factorix::Container.config }

  before do
    # Inject logger into runtime
    allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)

    # Reset config to defaults
    config.runtime.executable_path = nil
    config.runtime.user_dir = nil
    config.runtime.data_dir = nil
  end

  describe "#executable_path" do
    context "when configured" do
      let(:configured_path) { Pathname("/configured/factorio") }

      before do
        config.runtime.executable_path = configured_path
      end

      it "returns the configured path" do
        expect(runtime.executable_path).to eq(configured_path)
      end

      it "logs that configured path is used" do
        runtime.executable_path
        expect(logger).to have_received(:debug).with(
          "Using configured executable_path",
          path: configured_path.to_s
        )
      end

      it "does not call super (auto-detection)" do
        # If super was called, it would log auto-detection
        runtime.executable_path
        expect(logger).not_to have_received(:debug).with(
          "No configuration for executable_path, using auto-detection"
        )
      end
    end

    context "when not configured" do
      it "calls super for auto-detection" do
        expect(runtime.executable_path).to eq(Pathname("/auto/detected/factorio"))
      end

      it "logs that auto-detection is used" do
        runtime.executable_path
        expect(logger).to have_received(:debug).with(
          "No configuration for executable_path, using auto-detection"
        )
        expect(logger).to have_received(:debug).with(
          "Auto-detected executable_path",
          path: "/auto/detected/factorio"
        )
      end
    end

    context "when not configured and auto-detection fails" do
      let(:runtime) { failing_runtime_class.new }

      before do
        # Mock runtime to avoid chicken-and-egg problem with factorix_config_path
        allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(
          instance_double(
            Factorix::Runtime::Base,
            factorix_config_path: Pathname("/home/user/.config/factorix/config.rb")
          )
        )
        allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
      end

      it "raises ConfigurationError with helpful message" do
        expect { runtime.executable_path }.to raise_error(
          Factorix::ConfigurationError,
          /executable_path not configured and auto-detection is not supported/
        )
      end

      it "logs the error" do
        begin
          runtime.executable_path
        rescue Factorix::ConfigurationError
          # Expected
        end

        expect(logger).to have_received(:error).with(
          "Auto-detection failed and no configuration provided",
          error: /not implemented/
        )
      end

      it "includes configuration instructions in error message" do
        expect { runtime.executable_path }.to raise_error(
          Factorix::ConfigurationError,
          /Factorix::Container\.configure/
        )
      end
    end
  end

  describe "#user_dir" do
    context "when configured" do
      let(:configured_path) { Pathname("/configured/user") }

      before do
        config.runtime.user_dir = configured_path
      end

      it "returns the configured path" do
        expect(runtime.user_dir).to eq(configured_path)
      end

      it "logs that configured path is used" do
        runtime.user_dir
        expect(logger).to have_received(:debug).with(
          "Using configured user_dir",
          path: configured_path.to_s
        )
      end

      it "does not call super (auto-detection)" do
        runtime.user_dir
        expect(logger).not_to have_received(:debug).with(
          "No configuration for user_dir, using auto-detection"
        )
      end
    end

    context "when not configured" do
      it "calls super for auto-detection" do
        expect(runtime.user_dir).to eq(Pathname("/auto/detected/user"))
      end

      it "logs that auto-detection is used" do
        runtime.user_dir
        expect(logger).to have_received(:debug).with(
          "No configuration for user_dir, using auto-detection"
        )
        expect(logger).to have_received(:debug).with(
          "Auto-detected user_dir",
          path: "/auto/detected/user"
        )
      end
    end

    context "when not configured and auto-detection fails" do
      let(:runtime) { failing_runtime_class.new }

      before do
        # Mock runtime to avoid chicken-and-egg problem with factorix_config_path
        allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(
          instance_double(
            Factorix::Runtime::Base,
            factorix_config_path: Pathname("/home/user/.config/factorix/config.rb")
          )
        )
        allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
      end

      it "raises ConfigurationError with helpful message" do
        expect { runtime.user_dir }.to raise_error(
          Factorix::ConfigurationError,
          /user_dir not configured and auto-detection is not supported/
        )
      end

      it "logs the error" do
        begin
          runtime.user_dir
        rescue Factorix::ConfigurationError
          # Expected
        end

        expect(logger).to have_received(:error).with(
          "Auto-detection failed and no configuration provided",
          error: /not implemented/
        )
      end

      it "includes configuration instructions in error message" do
        expect { runtime.user_dir }.to raise_error(
          Factorix::ConfigurationError,
          /Factorix::Container\.configure/
        )
      end
    end
  end

  describe "#data_dir" do
    context "when configured" do
      let(:configured_path) { Pathname("/configured/data") }

      before do
        config.runtime.data_dir = configured_path
      end

      it "returns the configured path" do
        expect(runtime.data_dir).to eq(configured_path)
      end

      it "logs that configured path is used" do
        runtime.data_dir
        expect(logger).to have_received(:debug).with(
          "Using configured data_dir",
          path: configured_path.to_s
        )
      end

      it "does not call super (auto-detection)" do
        runtime.data_dir
        expect(logger).not_to have_received(:debug).with(
          "No configuration for data_dir, using auto-detection"
        )
      end
    end

    context "when not configured" do
      it "calls super for auto-detection" do
        expect(runtime.data_dir).to eq(Pathname("/auto/detected/data"))
      end

      it "logs that auto-detection is used" do
        runtime.data_dir
        expect(logger).to have_received(:debug).with(
          "No configuration for data_dir, using auto-detection"
        )
        expect(logger).to have_received(:debug).with(
          "Auto-detected data_dir",
          path: "/auto/detected/data"
        )
      end
    end

    context "when not configured and auto-detection fails" do
      let(:runtime) { failing_runtime_class.new }

      before do
        # Mock runtime to avoid chicken-and-egg problem with factorix_config_path
        allow(Factorix::Container).to receive(:[]).with(:runtime).and_return(
          instance_double(
            Factorix::Runtime::Base,
            factorix_config_path: Pathname("/home/user/.config/factorix/config.rb")
          )
        )
        allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
      end

      it "raises ConfigurationError with helpful message" do
        expect { runtime.data_dir }.to raise_error(
          Factorix::ConfigurationError,
          /data_dir not configured and auto-detection is not supported/
        )
      end

      it "logs the error" do
        begin
          runtime.data_dir
        rescue Factorix::ConfigurationError
          # Expected
        end

        expect(logger).to have_received(:error).with(
          "Auto-detection failed and no configuration provided",
          error: /not implemented/
        )
      end

      it "includes configuration instructions in error message" do
        expect { runtime.data_dir }.to raise_error(
          Factorix::ConfigurationError,
          /Factorix::Container\.configure/
        )
      end
    end
  end
end
