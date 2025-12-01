# frozen_string_literal: true

RSpec.describe Factorix::InfoJSON do
  describe ".from_json" do
    let(:valid_data) do
      {
        "name" => "test-mod",
        "version" => "1.2.3",
        "title" => "Test MOD",
        "author" => "Test Author",
        "description" => "A test MOD",
        "factorio_version" => "1.1",
        "dependencies" => ["base >= 1.0.0", "? optional-mod"]
      }
    end

    it "creates InfoJSON from valid JSON" do
      info = Factorix::InfoJSON.from_json(valid_data.to_json)

      expect(info.name).to eq("test-mod")
      expect(info.version).to eq(Factorix::MODVersion.from_string("1.2.3"))
      expect(info.title).to eq("Test MOD")
      expect(info.author).to eq("Test Author")
      expect(info.description).to eq("A test MOD")
      expect(info.factorio_version).to eq("1.1")
      expect(info.dependencies).to be_an(Array)
      expect(info.dependencies.size).to eq(2)
    end

    it "parses dependencies correctly" do
      info = Factorix::InfoJSON.from_json(valid_data.to_json)

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

      info = Factorix::InfoJSON.from_json(minimal_data.to_json)

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
        Factorix::InfoJSON.from_json(incomplete_data.to_json)
      }.to raise_error(Factorix::FileFormatError, /Missing required fields: title, author/)
    end

    it "raises ArgumentError for invalid version format" do
      invalid_version_data = valid_data.merge("version" => "invalid")

      expect {
        Factorix::InfoJSON.from_json(invalid_version_data.to_json)
      }.to raise_error(Factorix::FileFormatError, /invalid version string/)
    end

    it "raises ArgumentError for invalid JSON" do
      invalid_json = "{name: 'broken'"

      expect {
        Factorix::InfoJSON.from_json(invalid_json)
      }.to raise_error(Factorix::FileFormatError, /Invalid JSON/)
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
        "title" => "Zip MOD",
        "author" => "Zip Author"
      }.to_json

      Zip::File.open(zip_path, create: true) do |zipfile|
        zipfile.get_output_stream("test-mod/info.json") {|f| f.write(info_json_content) }
      end

      info = Factorix::InfoJSON.from_zip(zip_path)

      expect(info.name).to eq("zip-mod")
      expect(info.version.to_s).to eq("1.0.0")
      expect(info.title).to eq("Zip MOD")
      expect(info.author).to eq("Zip Author")
    end

    it "raises ArgumentError when info.json not found" do
      # Create zip without info.json
      Zip::File.open(zip_path, create: true) do |zipfile|
        zipfile.get_output_stream("test-mod/readme.txt") {|f| f.write("test") }
      end

      expect {
        Factorix::InfoJSON.from_zip(zip_path)
      }.to raise_error(Factorix::FileFormatError, /info.json not found/)
    end

    it "raises ArgumentError for invalid zip file" do
      # Create a non-zip file
      File.write(zip_path, "not a zip file")

      expect {
        Factorix::InfoJSON.from_zip(zip_path)
      }.to raise_error(Factorix::FileFormatError, /Invalid zip file/)
    end
  end
end
