# frozen_string_literal: true

RSpec.describe Factorix::Application do
  describe "deprecation warnings" do
    describe ".[]" do
      it "delegates to Container" do
        result = nil
        capture_stderr { result = Factorix::Application[:runtime] }
        expect(result).to be_a(Factorix::Runtime::Base)
      end

      it "outputs deprecation warning" do
        warning = capture_stderr { Factorix::Application[:runtime] }
        expect(warning).to match(/\[factorix\] Factorix::Application is deprecated, use Factorix::Container for DI/)
      end
    end

    describe ".resolve" do
      it "delegates to Container" do
        result = nil
        capture_stderr { result = Factorix::Application.resolve(:runtime) }
        expect(result).to be_a(Factorix::Runtime::Base)
      end

      it "outputs deprecation warning" do
        warning = capture_stderr { Factorix::Application.resolve(:runtime) }
        expect(warning).to match(/\[factorix\] Factorix::Application is deprecated, use Factorix::Container for DI/)
      end
    end

    describe ".config" do
      it "delegates to Factorix" do
        result = nil
        capture_stderr { result = Factorix::Application.config }
        expect(result).to eq(Factorix.config)
      end

      it "outputs deprecation warning" do
        warning = capture_stderr { Factorix::Application.config }
        expect(warning).to match(/\[factorix\] Factorix::Application is deprecated, use Factorix.config for configuration/)
      end
    end

    describe ".configure" do
      it "delegates to Factorix" do
        original_level = Factorix.config.log_level
        capture_stderr do
          Factorix::Application.configure do |config|
            config.log_level = :debug
          end
        end
        expect(Factorix.config.log_level).to eq(:debug)
        Factorix.config.log_level = original_level
      end

      it "outputs deprecation warning" do
        warning = capture_stderr { Factorix::Application.configure }
        expect(warning).to match(/\[factorix\] Factorix::Application is deprecated, use Factorix.configure for configuration/)
      end
    end
  end
end
