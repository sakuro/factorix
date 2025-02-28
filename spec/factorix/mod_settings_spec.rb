# frozen_string_literal: true

require "spec_helper"

RSpec.describe Factorix::ModSettings do
  let(:settings_path) { Pathname.new("/path/to/mod-settings.dat") }
  let(:deserializer) { instance_double(Factorix::Deserializer) }
  let(:raw_settings) do
    {
      "startup" => {
        "mod-a" => {"value" => true},
        "mod-b" => {"value" => 42}
      },
      "runtime-global" => {
        "mod-c" => {"value" => "value"},
        "mod-d" => {"value" => "rgba:ff0000ff"}
      },
      "runtime-per-user" => {
        "mod-e" => {"value" => [1, 2, 3]},
        "YARM-color-from" => {"value" => "rgba:ef6666ff"},
        "YARM-color-to" => {"value" => "rgba:00ef00ff"},
        "dolly-clear-entity" => {"value" => false}
      }
    }
  end

  before do
    allow(Factorix::Deserializer).to receive(:new).and_return(deserializer)
    allow(deserializer).to receive(:read_version64)
    allow(deserializer).to receive(:read_bool)
    allow(deserializer).to receive(:read_property_tree).and_return(raw_settings)
    allow(settings_path).to receive(:open).and_yield(StringIO.new)
  end

  describe "#initialize" do
    it "loads settings from the given path" do
      mod_settings = described_class.new(settings_path)

      expect(mod_settings["startup"]).to be_a(Factorix::ModSettings::Section)
      expect(mod_settings["runtime-global"]).to be_a(Factorix::ModSettings::Section)
      expect(mod_settings["runtime-per-user"]).to be_a(Factorix::ModSettings::Section)
    end

    it "raises InvalidModSectionError for invalid section names" do
      invalid_settings = {"invalid-section" => {}}
      allow(deserializer).to receive(:read_property_tree).and_return(invalid_settings)

      expect { described_class.new(settings_path) }.to raise_error(Factorix::InvalidModSectionError)
    end
  end

  describe "#[]" do
    let(:mod_settings) { described_class.new(settings_path) }

    it "returns the section with the given name" do
      section = mod_settings["startup"]

      expect(section).to be_a(Factorix::ModSettings::Section)
      expect(section.name).to eq("startup")
    end

    it "raises InvalidModSectionError for invalid section names" do
      expect { mod_settings["invalid"] }.to raise_error(Factorix::InvalidModSectionError)
    end

    it "raises ModSectionNotFoundError if the section doesn't exist" do
      # This shouldn't happen with the current implementation since all valid sections are created,
      # but we test it for completeness
      sections = mod_settings.instance_variable_get(:@sections)
      sections.delete("startup")

      expect { mod_settings["startup"] }.to raise_error(Factorix::ModSectionNotFoundError)
    end
  end

  describe "#each_section" do
    let(:mod_settings) { described_class.new(settings_path) }

    it "yields each section" do
      sections = []
      mod_settings.each_section {|section| sections << section }

      expect(sections.size).to eq(3)
      expect(sections.map(&:name)).to contain_exactly("startup", "runtime-global", "runtime-per-user")
    end

    it "returns an enumerator if no block is given" do
      expect(mod_settings.each_section).to be_a(Enumerator)
    end
  end

  describe Factorix::ModSettings::Section do
    let(:section) { Factorix::ModSettings::Section.new("startup") }

    describe "#initialize" do
      it "sets the name" do
        expect(section.name).to eq("startup")
      end

      it "raises InvalidModSectionError for invalid section names" do
        expect { Factorix::ModSettings::Section.new("invalid") }.to raise_error(Factorix::InvalidModSectionError)
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
        pairs = []
        section.each {|key, value| pairs << [key, value] }

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
  end
end
