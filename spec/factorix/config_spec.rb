# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::Config do
  describe ".default" do
    let(:config) { Factorix::Config.default }

    it "has log_level :info" do
      expect(config.log_level).to eq(:info)
    end

    it "has RCON defaults" do
      expect(config.rcon.host).to eq("localhost")
      expect(config.rcon.port).to eq(27015)
      expect(config.rcon.password).to be_nil
    end

    it "has HTTP timeout defaults" do
      expect(config.http.connect_timeout).to eq(5)
      expect(config.http.read_timeout).to eq(30)
      expect(config.http.write_timeout).to eq(30)
    end

    it "has no runtime path overrides" do
      expect(config.runtime.executable_path).to be_nil
      expect(config.runtime.user_dir).to be_nil
      expect(config.runtime.data_dir).to be_nil
    end

    it "has download cache defaults" do
      expect(config.cache.download.backend).to eq(:file_system)
      expect(config.cache.download.ttl).to be_nil
      expect(config.cache.download.file_system.max_file_size).to be_nil
    end

    it "has api cache defaults" do
      expect(config.cache.api.backend).to eq(:file_system)
      expect(config.cache.api.ttl).to eq(3600)
      expect(config.cache.api.file_system.max_file_size).to eq(10 * 1024 * 1024)
      expect(config.cache.api.file_system.compression_threshold).to eq(0)
    end

    it "has info_json cache defaults" do
      expect(config.cache.info_json.backend).to eq(:file_system)
      expect(config.cache.info_json.ttl).to be_nil
    end
  end

  describe ".from_h" do
    it "overrides defaults with given values" do
      config = Factorix::Config.from_h(log_level: "debug", http: {connect_timeout: 10})

      expect(config.log_level).to eq(:debug)
      expect(config.http.connect_timeout).to eq(10)
      expect(config.http.read_timeout).to eq(30)
    end

    it "converts runtime paths to Pathname" do
      config = Factorix::Config.from_h(runtime: {user_dir: "/path/to/user"})

      expect(config.runtime.user_dir).to eq(Pathname("/path/to/user"))
    end

    it "converts cache backend to Symbol" do
      config = Factorix::Config.from_h(cache: {api: {backend: "redis"}})

      expect(config.cache.api.backend).to eq(:redis)
    end

    it "raises ConfigurationError for an unknown key" do
      expect {
        Factorix::Config.from_h(cache: {api: {unknown_key: 1}})
      }.to raise_error(Factorix::ConfigurationError, /Unknown configuration key: cache.api.unknown_key/)
    end

    it "raises ConfigurationError when a table is given a scalar" do
      expect {
        Factorix::Config.from_h(http: 10)
      }.to raise_error(Factorix::ConfigurationError, /http must be a table/)
    end
  end

  describe ".load_file" do
    it "loads configuration from a TOML file" do
      Tempfile.create(["config", ".toml"]) do |file|
        file.write(<<~TOML)
          log_level = "warn"

          [rcon]
          host = "game.example.com"

          [cache.api]
          ttl = 7200
        TOML
        file.close

        config = Factorix::Config.load_file(Pathname(file.path))

        expect(config.log_level).to eq(:warn)
        expect(config.rcon.host).to eq("game.example.com")
        expect(config.cache.api.ttl).to eq(7200)
      end
    end

    it "raises ConfigurationError for invalid TOML" do
      Tempfile.create(["config", ".toml"]) do |file|
        file.write("log_level = ")
        file.close

        expect {
          Factorix::Config.load_file(Pathname(file.path))
        }.to raise_error(Factorix::ConfigurationError, /Invalid TOML/)
      end
    end
  end

  describe "#cache" do
    it "exposes cache types via to_h" do
      expect(Factorix::Config.default.cache.to_h.keys).to eq(%i[download api info_json])
    end
  end
end
