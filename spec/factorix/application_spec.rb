# frozen_string_literal: true

RSpec.describe Factorix::Application do
  # Suppress deprecation warnings during delegation tests
  def with_suppressed_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original
  end

  describe "deprecation warnings" do
    describe ".[]" do
      it "delegates to Container" do
        result = with_suppressed_stderr { Factorix::Application[:runtime] }
        expect(result).to be_a(Factorix::Runtime::Base)
      end

      it "outputs deprecation warning" do
        expect { Factorix::Application[:runtime] }
          .to output(/\[factorix\] Factorix::Application is deprecated, use Factorix::Container for DI/).to_stderr
      end
    end

    describe ".resolve" do
      it "delegates to Container" do
        result = with_suppressed_stderr { Factorix::Application.resolve(:runtime) }
        expect(result).to be_a(Factorix::Runtime::Base)
      end

      it "outputs deprecation warning" do
        expect { Factorix::Application.resolve(:runtime) }
          .to output(/\[factorix\] Factorix::Application is deprecated, use Factorix::Container for DI/).to_stderr
      end
    end

    describe ".config" do
      it "delegates to Factorix" do
        result = with_suppressed_stderr { Factorix::Application.config }
        expect(result).to eq(Factorix.config)
      end

      it "outputs deprecation warning" do
        expect { Factorix::Application.config }
          .to output(/\[factorix\] Factorix::Application is deprecated, use Factorix.config for configuration/).to_stderr
      end
    end

    describe ".configure" do
      it "delegates to Factorix" do
        original_level = Factorix.config.log_level
        with_suppressed_stderr do
          Factorix::Application.configure do |config|
            config.log_level = :debug
          end
        end
        expect(Factorix.config.log_level).to eq(:debug)
        Factorix.config.log_level = original_level
      end

      it "outputs deprecation warning" do
        expect { Factorix::Application.configure }
          .to output(/\[factorix\] Factorix::Application is deprecated, use Factorix.configure for configuration/).to_stderr
      end
    end
  end
end
