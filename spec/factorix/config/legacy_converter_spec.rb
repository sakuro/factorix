# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::Config::LegacyConverter do
  def convert(source)
    Tempfile.create(["config", ".rb"]) do |file|
      file.write(source)
      file.close
      Factorix::Config::LegacyConverter.convert(Pathname(file.path))
    end
  end

  it "converts flat and nested assignments to TOML" do
    toml = convert(<<~RUBY)
      configure do |config|
        config.log_level = :debug
        config.rcon.host = "game.example.com"
        config.rcon.port = 27016
      end
    RUBY

    expect(toml).to include('log_level = "debug"')
    expect(toml).to include("[rcon]")
    expect(toml).to include('host = "game.example.com"')
    expect(toml).to include("port = 27016")
  end

  it "converts Pathname values to strings" do
    toml = convert(<<~RUBY)
      configure do |config|
        config.runtime.user_dir = Pathname("/srv/factorio")
      end
    RUBY

    expect(toml).to include('user_dir = "/srv/factorio"')
  end

  it "drops nil assignments" do
    toml = convert(<<~RUBY)
      configure do |config|
        config.rcon.password = nil
        config.rcon.port = 27016
      end
    RUBY

    expect(toml).not_to include("password")
    expect(toml).to include("port = 27016")
  end

  it "produces TOML that Config.load_file accepts" do
    toml = convert(<<~RUBY)
      configure do |config|
        config.log_level = :warn
        config.cache.api.backend = :redis
        config.cache.api.redis.url = "redis://localhost:6379/0"
      end
    RUBY

    Tempfile.create(["config", ".toml"]) do |file|
      file.write(toml)
      file.close

      config = Factorix::Config.load_file(Pathname(file.path))
      expect(config.log_level).to eq(:warn)
      expect(config.cache.api.backend).to eq(:redis)
      expect(config.cache.api.redis.url).to eq("redis://localhost:6379/0")
    end
  end
end
