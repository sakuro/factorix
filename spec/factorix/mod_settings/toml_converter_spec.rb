# frozen_string_literal: true

RSpec.describe Factorix::MODSettings::TOMLConverter do
  subject(:converter) { Factorix::MODSettings::TOMLConverter.new }

  let(:game_version) { Factorix::Types::GameVersion.from_string("1.1.0-42") }
  let(:startup_section) do
    section = Factorix::MODSettings::Section.new("startup")
    section["string-value"] = "test"
    section["bool-value"] = true
    section["float-value"] = 1.5
    section["signed-int"] = Factorix::Types::SignedInteger.new(42)
    section["unsigned-int"] = Factorix::Types::UnsignedInteger.new(100)
    section
  end
  let(:sections) { {"startup" => startup_section} }
  let(:settings) { Factorix::MODSettings.new(game_version, sections) }

  describe "#convert_to" do
    it "converts MODSettings to TOML string" do
      toml = converter.convert_to(settings)

      expect(toml).to include('game_version = "1.1.0-42"')
      expect(toml).to include("[startup]")
      expect(toml).to include('string-value = "test"')
      expect(toml).to include("bool-value = true")
      expect(toml).to include("float-value = 1.5")
    end

    it "converts SignedInteger to plain integer" do
      toml = converter.convert_to(settings)

      expect(toml).to include("signed-int = 42")
      expect(toml).not_to include("SignedInteger")
    end

    it "converts UnsignedInteger to plain integer" do
      toml = converter.convert_to(settings)

      expect(toml).to include("unsigned-int = 100")
      expect(toml).not_to include("UnsignedInteger")
    end
  end

  describe "#convert_from" do
    let(:toml_string) do
      <<~TOML
        game_version = "1.1.0-42"

        [startup]
        string-value = "test"
        bool-value = true
        float-value = 1.5
        int-value = 42
      TOML
    end

    it "converts TOML string to MODSettings" do
      result = converter.convert_from(toml_string)

      expect(result.game_version).to eq(game_version)
      expect(result["startup"]["string-value"]).to eq("test")
      expect(result["startup"]["bool-value"]).to be(true)
      expect(result["startup"]["float-value"]).to eq(1.5)
    end

    it "converts integers to SignedInteger by default" do
      result = converter.convert_from(toml_string)

      expect(result["startup"]["int-value"]).to be_a(Factorix::Types::SignedInteger)
      expect(Integer(result["startup"]["int-value"].to_s, 10)).to eq(42)
    end

    it "creates all valid sections even if empty" do
      result = converter.convert_from(toml_string)

      expect(result["startup"]).not_to be_empty
      expect(result["runtime-global"]).to be_empty
      expect(result["runtime-per-user"]).to be_empty
    end
  end

  describe "roundtrip conversion" do
    it "preserves data through convert_to and convert_from" do
      toml = converter.convert_to(settings)
      result = converter.convert_from(toml)

      expect(result.game_version).to eq(settings.game_version)
      expect(result["startup"]["string-value"]).to eq("test")
      expect(result["startup"]["bool-value"]).to be(true)
      expect(result["startup"]["float-value"]).to eq(1.5)
      # NOTE: SignedInteger/UnsignedInteger distinction is lost in TOML
      expect(Integer(result["startup"]["signed-int"].to_s, 10)).to eq(42)
      expect(Integer(result["startup"]["unsigned-int"].to_s, 10)).to eq(100)
    end
  end
end
