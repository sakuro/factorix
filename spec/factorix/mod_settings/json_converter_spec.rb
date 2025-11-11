# frozen_string_literal: true

RSpec.describe Factorix::MODSettings::JSONConverter do
  subject(:converter) { Factorix::MODSettings::JSONConverter.new }

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
    it "converts MODSettings to JSON string" do
      json = converter.convert_to(settings)
      parsed = JSON.parse(json)

      expect(parsed["game_version"]).to eq("1.1.0-42")
      expect(parsed["startup"]).to be_a(Hash)
      expect(parsed["startup"]["string-value"]).to eq("test")
      expect(parsed["startup"]["bool-value"]).to be(true)
      expect(parsed["startup"]["float-value"]).to eq(1.5)
    end

    it "converts SignedInteger to plain integer" do
      json = converter.convert_to(settings)
      parsed = JSON.parse(json)

      expect(parsed["startup"]["signed-int"]).to eq(42)
      expect(parsed["startup"]["signed-int"]).to be_an(Integer)
    end

    it "converts UnsignedInteger to plain integer" do
      json = converter.convert_to(settings)
      parsed = JSON.parse(json)

      expect(parsed["startup"]["unsigned-int"]).to eq(100)
      expect(parsed["startup"]["unsigned-int"]).to be_an(Integer)
    end
  end

  describe "#convert_from" do
    let(:json_string) do
      <<~JSON
        {
          "game_version": "1.1.0-42",
          "startup": {
            "string-value": "test",
            "bool-value": true,
            "float-value": 1.5,
            "int-value": 42
          }
        }
      JSON
    end

    it "converts JSON string to MODSettings" do
      result = converter.convert_from(json_string)

      expect(result.game_version).to eq(game_version)
      expect(result["startup"]["string-value"]).to eq("test")
      expect(result["startup"]["bool-value"]).to be(true)
      expect(result["startup"]["float-value"]).to eq(1.5)
    end

    it "converts integers to SignedInteger by default" do
      result = converter.convert_from(json_string)

      expect(result["startup"]["int-value"]).to be_a(Factorix::Types::SignedInteger)
      expect(Integer(result["startup"]["int-value"].to_s, 10)).to eq(42)
    end

    it "creates all valid sections even if empty" do
      result = converter.convert_from(json_string)

      expect(result["startup"]).not_to be_empty
      expect(result["runtime-global"]).to be_empty
      expect(result["runtime-per-user"]).to be_empty
    end
  end

  describe "roundtrip conversion" do
    it "preserves data through convert_to and convert_from" do
      json = converter.convert_to(settings)
      result = converter.convert_from(json)

      expect(result.game_version).to eq(settings.game_version)
      expect(result["startup"]["string-value"]).to eq("test")
      expect(result["startup"]["bool-value"]).to be(true)
      expect(result["startup"]["float-value"]).to eq(1.5)
      # NOTE: SignedInteger/UnsignedInteger distinction is lost in JSON
      expect(Integer(result["startup"]["signed-int"].to_s, 10)).to eq(42)
      expect(Integer(result["startup"]["unsigned-int"].to_s, 10)).to eq(100)
    end
  end
end
