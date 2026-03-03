# frozen_string_literal: true

require "base64"
require "zlib"

RSpec.describe Factorix::Blueprint do
  let(:data) { {"blueprint" => {"item" => "blueprint", "version" => 1}} }
  let(:json_string) { JSON.generate(data) }
  let(:compressed) { Zlib::Deflate.deflate(json_string) }
  let(:valid_blueprint_string) { "0#{Base64.strict_encode64(compressed)}" }

  describe ".new" do
    it "creates a blueprint with the given data" do
      blueprint = Factorix::Blueprint.new(data)
      expect(blueprint.data).to eq(data)
    end
  end

  describe ".decode" do
    it "decodes a valid blueprint string" do
      blueprint = Factorix::Blueprint.decode(valid_blueprint_string)
      expect(blueprint.data).to eq(data)
    end

    it "raises UnsupportedBlueprintVersionError for unknown version byte" do
      invalid = "1#{Base64.strict_encode64(compressed)}"
      expect { Factorix::Blueprint.decode(invalid) }.to raise_error(Factorix::UnsupportedBlueprintVersionError)
    end

    it "raises BlueprintFormatError for invalid Base64" do
      expect { Factorix::Blueprint.decode("0!!!invalid!!!") }.to raise_error(Factorix::BlueprintFormatError)
    end

    it "raises BlueprintFormatError for invalid zlib data" do
      expect { Factorix::Blueprint.decode("0#{Base64.strict_encode64("not zlib")}") }.to raise_error(Factorix::BlueprintFormatError)
    end

    it "raises BlueprintFormatError for invalid JSON" do
      bad_json = Zlib::Deflate.deflate("not json")
      expect { Factorix::Blueprint.decode("0#{Base64.strict_encode64(bad_json)}") }.to raise_error(Factorix::BlueprintFormatError)
    end
  end

  describe "#encode" do
    it "encodes the blueprint data to a blueprint string" do
      blueprint = Factorix::Blueprint.new(data)
      result = blueprint.encode
      expect(result[0]).to eq("0")
    end

    it "round-trips with decode" do
      original = Factorix::Blueprint.decode(valid_blueprint_string)
      re_encoded = original.encode
      round_tripped = Factorix::Blueprint.decode(re_encoded)
      expect(round_tripped.data).to eq(data)
    end
  end

  describe "#to_json" do
    it "returns pretty-printed JSON" do
      blueprint = Factorix::Blueprint.new(data)
      result = blueprint.to_json
      expect(result).to eq(JSON.pretty_generate(data))
    end
  end
end
