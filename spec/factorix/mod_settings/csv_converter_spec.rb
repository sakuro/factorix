# frozen_string_literal: true

RSpec.describe Factorix::MODSettings::CSVConverter do
  subject(:converter) { Factorix::MODSettings::CSVConverter.new }

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
    it "converts MODSettings to CSV string" do
      csv = converter.convert_to(settings)
      lines = csv.lines.map(&:chomp)

      expect(lines[0]).to eq("section,name,value")
      expect(lines[1]).to eq("startup,string-value,test")
      expect(lines[2]).to eq("startup,bool-value,true")
      expect(lines[3]).to eq("startup,float-value,1.5")
    end

    it "converts SignedInteger to plain integer" do
      csv = converter.convert_to(settings)

      expect(csv).to include("startup,signed-int,42")
      expect(csv).not_to include("SignedInteger")
    end

    it "converts UnsignedInteger to plain integer" do
      csv = converter.convert_to(settings)

      expect(csv).to include("startup,unsigned-int,100")
      expect(csv).not_to include("UnsignedInteger")
    end

    it "includes header row" do
      csv = converter.convert_to(settings)

      expect(csv.lines.first.chomp).to eq("section,name,value")
    end

    it "does not include game_version" do
      csv = converter.convert_to(settings)

      expect(csv).not_to include("game_version")
      expect(csv).not_to include("1.1.0-42")
    end
  end

  describe "#convert_from" do
    it "raises NotImplementedError" do
      csv_string = "section,name,value\nstartup,test,value"

      expect {
        converter.convert_from(csv_string)
      }.to raise_error(NotImplementedError, /CSV format does not support restore operation/)
    end
  end
end
