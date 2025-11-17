# frozen_string_literal: true

RSpec.describe Factorix::Types::InfoJSON do
  describe ".from_hash" do
    let(:valid_data) do
      {
        "name" => "test-mod",
        "version" => "1.2.3",
        "title" => "Test Mod",
        "author" => "Test Author",
        "description" => "A test mod",
        "factorio_version" => "1.1",
        "dependencies" => ["base >= 1.0.0", "? optional-mod"]
      }
    end

    it "creates InfoJSON from valid hash" do
      info = Factorix::Types::InfoJSON.from_hash(valid_data)

      expect(info.name).to eq("test-mod")
      expect(info.version).to eq(Factorix::Types::MODVersion.from_string("1.2.3"))
      expect(info.title).to eq("Test Mod")
      expect(info.author).to eq("Test Author")
      expect(info.description).to eq("A test mod")
      expect(info.factorio_version).to eq("1.1")
      expect(info.dependencies).to be_an(Array)
      expect(info.dependencies.size).to eq(2)
    end

    it "parses dependencies correctly" do
      info = Factorix::Types::InfoJSON.from_hash(valid_data)

      expect(info.dependencies[0]).to be_a(Factorix::Dependency::Entry)
      expect(info.dependencies[0].mod.name).to eq("base")
      expect(info.dependencies[0].required?).to be true

      expect(info.dependencies[1]).to be_a(Factorix::Dependency::Entry)
      expect(info.dependencies[1].mod.name).to eq("optional-mod")
      expect(info.dependencies[1].optional?).to be true
    end

    it "handles missing optional fields" do
      minimal_data = {
        "name" => "minimal-mod",
        "version" => "0.1.0",
        "title" => "Minimal",
        "author" => "Author"
      }

      info = Factorix::Types::InfoJSON.from_hash(minimal_data)

      expect(info.description).to eq("")
      expect(info.factorio_version).to be_nil
      expect(info.dependencies).to eq([])
    end

    it "raises ArgumentError for missing required fields" do
      incomplete_data = {
        "name" => "incomplete",
        "version" => "1.0.0"
        # missing title and author
      }

      expect {
        Factorix::Types::InfoJSON.from_hash(incomplete_data)
      }.to raise_error(ArgumentError, /Missing required fields: title, author/)
    end

    it "raises ArgumentError for invalid version format" do
      invalid_version_data = valid_data.merge("version" => "invalid")

      expect {
        Factorix::Types::InfoJSON.from_hash(invalid_version_data)
      }.to raise_error(ArgumentError, /invalid version string/)
    end
  end

  describe ".from_json" do
    it "parses JSON string" do
      json_string = <<~JSON
        {
          "name": "json-mod",
          "version": "2.0.0",
          "title": "JSON Mod",
          "author": "JSON Author"
        }
      JSON

      info = Factorix::Types::InfoJSON.from_json(json_string)

      expect(info.name).to eq("json-mod")
      expect(info.version.to_s).to eq("2.0.0")
    end

    it "raises ArgumentError for invalid JSON" do
      invalid_json = "{name: 'broken'"

      expect {
        Factorix::Types::InfoJSON.from_json(invalid_json)
      }.to raise_error(ArgumentError, /Invalid JSON/)
    end
  end

  describe ".from_zip" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:zip_path) { Pathname(temp_dir) / "test-mod_1.0.0.zip" }

    after do
      FileUtils.remove_entry(temp_dir)
    end

    it "extracts info.json from zip file" do
      # Create a test zip file with info.json
      info_json_content = {
        "name" => "zip-mod",
        "version" => "1.0.0",
        "title" => "Zip Mod",
        "author" => "Zip Author"
      }.to_json

      Zip::File.open(zip_path, create: true) do |zipfile|
        zipfile.get_output_stream("test-mod/info.json") {|f| f.write(info_json_content) }
      end

      info = Factorix::Types::InfoJSON.from_zip(zip_path)

      expect(info.name).to eq("zip-mod")
      expect(info.version.to_s).to eq("1.0.0")
      expect(info.title).to eq("Zip Mod")
      expect(info.author).to eq("Zip Author")
    end

    it "raises ArgumentError when info.json not found" do
      # Create zip without info.json
      Zip::File.open(zip_path, create: true) do |zipfile|
        zipfile.get_output_stream("test-mod/readme.txt") {|f| f.write("test") }
      end

      expect {
        Factorix::Types::InfoJSON.from_zip(zip_path)
      }.to raise_error(ArgumentError, /info.json not found/)
    end

    it "raises ArgumentError for invalid zip file" do
      # Create a non-zip file
      File.write(zip_path, "not a zip file")

      expect {
        Factorix::Types::InfoJSON.from_zip(zip_path)
      }.to raise_error(ArgumentError, /Invalid zip file/)
    end
  end
end
