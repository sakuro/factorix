# frozen_string_literal: true

require "tmpdir"

RSpec.describe Factorix do
  after do
    Factorix.reset_config
  end

  describe ".load_config" do
    context "with an explicit TOML path" do
      it "loads the configuration" do
        Dir.mktmpdir do |dir|
          path = Pathname(dir) / "config.toml"
          path.write(%(log_level = "debug"\n))

          Factorix.load_config(path)

          expect(Factorix.config.log_level).to eq(:debug)
        end
      end
    end

    context "with an explicit path that does not exist" do
      it "raises ConfigurationError" do
        expect {
          Factorix.load_config(Pathname("/nonexistent/config.toml"))
        }.to raise_error(Factorix::ConfigurationError, /not found/)
      end
    end

    context "with an explicit legacy Ruby config" do
      it "raises ConfigurationError containing the equivalent TOML" do
        Dir.mktmpdir do |dir|
          path = Pathname(dir) / "config.rb"
          path.write(<<~RUBY)
            configure do |config|
              config.log_level = :debug
            end
          RUBY

          expect {
            Factorix.load_config(path)
          }.to raise_error(Factorix::ConfigurationError, /log_level = "debug"/)
        end
      end
    end

    context "without a path" do
      let(:runtime) { instance_double(Factorix::Runtime::Base) }

      before do
        allow(Factorix.app).to receive(:runtime).and_return(runtime)
      end

      it "loads the default config.toml when present" do
        Dir.mktmpdir do |dir|
          default_path = Pathname(dir) / "config.toml"
          default_path.write(%(log_level = "warn"\n))
          allow(runtime).to receive(:factorix_config_path).and_return(default_path)

          Factorix.load_config

          expect(Factorix.config.log_level).to eq(:warn)
        end
      end

      it "reports a legacy config.rb next to the default path" do
        Dir.mktmpdir do |dir|
          default_path = Pathname(dir) / "config.toml"
          legacy_path = Pathname(dir) / "config.rb"
          legacy_path.write(<<~RUBY)
            configure do |config|
              config.rcon.port = 27016
            end
          RUBY
          allow(runtime).to receive(:factorix_config_path).and_return(default_path)

          expect {
            Factorix.load_config
          }.to raise_error(Factorix::ConfigurationError, /port = 27016/)
        end
      end

      it "keeps defaults when no configuration exists" do
        Dir.mktmpdir do |dir|
          allow(runtime).to receive(:factorix_config_path).and_return(Pathname(dir) / "config.toml")

          Factorix.load_config

          expect(Factorix.config.log_level).to eq(:info)
        end
      end
    end
  end

  describe ".config" do
    it "returns defaults until configuration is loaded" do
      expect(Factorix.config.log_level).to eq(:info)
    end
  end
end
