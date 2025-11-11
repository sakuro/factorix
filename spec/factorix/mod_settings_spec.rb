# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::MODSettings do
  let(:settings_path) { Pathname.new("spec/fixtures/mod-settings/settings.dat") }
  let(:settings) { Factorix::MODSettings.load(from: settings_path) }
  let(:deserializer) { instance_double(Factorix::SerDes::Deserializer, eof?: true) }
  let(:game_version) { Factorix::Types::GameVersion.from_string("1.1.110-0") }
  let(:raw_settings) do
    {
      "startup" => {
        "mod-a-setting-1" => {"value" => true},
        "mod-a-setting-2" => {"value" => Factorix::Types::SignedInteger.new(42)},
        "mod-b-setting-1" => {"value" => "test"},
        "mod-b-setting-2" => {"value" => 3.14}
      },
      "runtime-global" => {
        "mod-c-setting-1" => {"value" => "value"},
        "mod-c-setting-2" => {"value" => {"r" => 1.0, "g" => 0.0, "b" => 0.0, "a" => 1.0}},
        "mod-c-setting-3" => {"value" => Factorix::Types::UnsignedInteger.new(100)}
      },
      "runtime-per-user" => {
        "mod-d-setting-1" => {"value" => Factorix::Types::UnsignedInteger.new(50)},
        "mod-d-setting-2" => {"value" => {"r" => 239 / 255.0, "g" => 102 / 255.0, "b" => 102 / 255.0, "a" => 1.0}},
        "mod-e-setting-1" => {"value" => {"r" => 0.0, "g" => 239 / 255.0, "b" => 0.0, "a" => 1.0}},
        "mod-e-setting-2" => {"value" => false},
        "mod-e-setting-3" => {"value" => 2.5}
      }
    }
  end

  before do
    allow(Factorix::SerDes::Deserializer).to receive(:new).and_return(deserializer)
    allow(deserializer).to receive_messages(
      read_game_version: game_version,
      read_bool: nil,
      read_property_tree: raw_settings
    )
    allow(settings_path).to receive(:open).and_yield(StringIO.new)
  end

  describe ".load" do
    context "when from: is specified" do
      let(:loaded_settings) { Factorix::MODSettings.load(from: settings_path) }

      it "loads settings from the given path" do
        expect(loaded_settings["startup"]).to be_a(Factorix::MODSettings::Section)
        expect(loaded_settings["runtime-global"]).to be_a(Factorix::MODSettings::Section)
        expect(loaded_settings["runtime-per-user"]).to be_a(Factorix::MODSettings::Section)
      end

      it "raises InvalidMODSectionError for invalid section names" do
        invalid_settings = {"invalid-section" => {}}
        allow(deserializer).to receive(:read_property_tree).and_return(invalid_settings)

        expect { Factorix::MODSettings.load(from: settings_path) }.to raise_error(Factorix::InvalidMODSectionError)
      end

      it "raises ExtraDataError if extra data exists at the end of file" do
        allow(deserializer).to receive_messages(eof?: false, read_property_tree: raw_settings)

        expect { Factorix::MODSettings.load(from: settings_path) }.to raise_error(Factorix::ExtraDataError)
      end
    end
  end

  describe "#[]" do
    it "returns the section with the given name" do
      section = settings["startup"]

      expect(section).to be_a(Factorix::MODSettings::Section)
      expect(section.name).to eq("startup")
    end

    it "raises InvalidMODSectionError for invalid section names" do
      expect { settings["invalid"] }.to raise_error(Factorix::InvalidMODSectionError)
    end

    it "raises MODSectionNotFoundError if the section doesn't exist" do
      # This shouldn't happen with the current implementation since all valid sections are created,
      # but we test it for completeness
      sections_hash = settings.instance_variable_get(:@sections)
      sections_hash.delete("startup")

      expect { settings["startup"] }.to raise_error(Factorix::MODSectionNotFoundError)
    end
  end

  describe "#each_section" do
    it "yields each section" do
      sections = []
      settings.each_section {|section| sections << section }

      expect(sections.size).to eq(3)
      expect(sections.map(&:name)).to contain_exactly("startup", "runtime-global", "runtime-per-user")
    end

    it "returns an enumerator if no block is given" do
      expect(settings.each_section).to be_a(Enumerator)
    end
  end

  describe "#game_version" do
    it "returns the game version" do
      expect(settings.game_version).to eq(game_version)
    end
  end

  describe "#save" do
    let(:temp_file) { Tempfile.new(%w[mod-settings- .dat]) }
    let(:temp_path) { Pathname(temp_file.path) }
    let(:serializer) { instance_double(Factorix::SerDes::Serializer) }

    after do
      temp_file.close
      temp_file.unlink
    end

    before do
      allow(Factorix::SerDes::Serializer).to receive(:new).and_return(serializer)
      allow(serializer).to receive_messages(
        write_game_version: nil,
        write_bool: nil,
        write_property_tree: nil
      )
    end

    context "when to: is specified" do
      it "saves settings to the specified path" do
        settings.save(to: temp_path)

        expect(serializer).to have_received(:write_game_version).with(game_version)
        expect(serializer).to have_received(:write_bool).with(false)
        expect(serializer).to have_received(:write_property_tree)
      end
    end
  end

  describe Factorix::MODSettings::Section do
    let(:section) { Factorix::MODSettings::Section.new("startup") }

    describe "#initialize" do
      it "sets the name" do
        expect(section.name).to eq("startup")
      end

      it "raises InvalidMODSectionError for invalid section names" do
        expect { Factorix::MODSettings::Section.new("invalid") }.to raise_error(Factorix::InvalidMODSectionError)
      end
    end

    describe "#[]= and #[]" do
      it "sets and gets values" do
        section["key"] = "value"

        expect(section["key"]).to eq("value")
      end
    end

    describe "#each" do
      before do
        section["key1"] = "value1"
        section["key2"] = "value2"
      end

      it "yields each key-value pair" do
        pairs = section.map {|key, value| [key, value] }

        expect(pairs).to contain_exactly(%w[key1 value1], %w[key2 value2])
      end

      it "returns an enumerator if no block is given" do
        expect(section.each).to be_a(Enumerator)
      end
    end

    describe "#empty?" do
      it "returns true if the section has no settings" do
        expect(section.empty?).to be(true)
      end

      it "returns false if the section has settings" do
        section["key"] = "value"

        expect(section.empty?).to be(false)
      end
    end

    describe "#key?" do
      before do
        section["existing"] = "value"
        section["false_value"] = false
      end

      it "returns true if the key exists" do
        expect(section.key?("existing")).to be(true)
      end

      it "returns true even if the value is false" do
        expect(section.key?("false_value")).to be(true)
      end

      it "returns false if the key does not exist" do
        expect(section.key?("nonexistent")).to be(false)
      end

      it "has alias has_key?" do
        expect(section.method(:has_key?)).to eq(section.method(:key?))
      end

      it "has alias include?" do
        expect(section.method(:include?)).to eq(section.method(:key?))
      end
    end

    describe "#keys" do
      before do
        section["key1"] = "value1"
        section["key2"] = "value2"
      end

      it "returns an array of all keys" do
        expect(section.keys).to contain_exactly("key1", "key2")
      end

      it "returns an empty array for empty section" do
        empty_section = Factorix::MODSettings::Section.new("runtime-global")
        expect(empty_section.keys).to eq([])
      end
    end

    describe "#values" do
      before do
        section["key1"] = "value1"
        section["key2"] = "value2"
      end

      it "returns an array of all values" do
        expect(section.values).to contain_exactly("value1", "value2")
      end

      it "returns an empty array for empty section" do
        empty_section = Factorix::MODSettings::Section.new("runtime-global")
        expect(empty_section.values).to eq([])
      end
    end

    describe "#size" do
      it "returns 0 for empty section" do
        expect(section.size).to eq(0)
      end

      it "returns the number of settings" do
        section["key1"] = "value1"
        section["key2"] = "value2"

        expect(section.size).to eq(2)
      end

      it "has alias length" do
        expect(section.method(:length)).to eq(section.method(:size))
      end
    end

    describe "#fetch" do
      before do
        section["existing"] = "value"
      end

      it "returns the value if key exists" do
        expect(section.fetch("existing")).to eq("value")
      end

      it "raises KeyError if key doesn't exist and no default given" do
        expect { section.fetch("nonexistent") }.to raise_error(KeyError)
      end

      it "returns default value if key doesn't exist" do
        expect(section.fetch("nonexistent", "default")).to eq("default")
      end

      it "yields to block if key doesn't exist" do
        result = section.fetch("nonexistent") {|key| "computed_#{key}" }
        expect(result).to eq("computed_nonexistent")
      end

      it "prefers block over default value" do
        result = section.fetch("nonexistent") {|key| "block_#{key}" }
        expect(result).to eq("block_nonexistent")
      end
    end

    describe "#to_h" do
      before do
        section["key1"] = "value1"
        section["key2"] = "value2"
      end

      it "returns a Hash of all settings" do
        expect(section.to_h).to eq({"key1" => "value1", "key2" => "value2"})
      end

      it "returns a copy, not the internal hash" do
        hash = section.to_h
        hash["key3"] = "value3"

        expect(section["key3"]).to be_nil
      end

      it "returns an empty hash for empty section" do
        empty_section = Factorix::MODSettings::Section.new("runtime-global")
        expect(empty_section.to_h).to eq({})
      end
    end
  end
end
