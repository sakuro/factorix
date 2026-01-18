# frozen_string_literal: true

require "tmpdir"
require "zip"

RSpec.describe Factorix::CLI::Commands::MOD::Upload do
  let(:portal) { instance_double(Factorix::Portal) }
  let(:mod_management_api) { instance_double(Factorix::API::MODManagementAPI) }
  let(:uploader) { instance_double(Factorix::Transfer::Uploader) }
  let(:command) { Factorix::CLI::Commands::MOD::Upload.new(portal:) }

  let(:temp_dir) { Dir.mktmpdir }
  let(:zip_path) { Pathname(temp_dir) / "test-mod_1.0.0.zip" }

  before do
    # Create a test zip file with info.json
    info_json_content = {
      "name" => "test-mod",
      "version" => "1.0.0",
      "title" => "Test MOD",
      "author" => "Test Author"
    }.to_json

    Zip::File.open(zip_path, create: true) do |zipfile|
      zipfile.get_output_stream("test-mod/info.json") {|f| f.write(info_json_content) }
    end

    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)
    allow(portal).to receive(:mod_management_api).and_return(mod_management_api)
    allow(mod_management_api).to receive(:uploader).and_return(uploader)
    allow(uploader).to receive(:subscribe)
    allow(uploader).to receive(:unsubscribe)
    allow(portal).to receive(:upload_mod)
  end

  after do
    FileUtils.remove_entry(temp_dir)
  end

  describe "#call" do
    it "uploads a MOD without metadata" do
      command.call(file: zip_path.to_s)

      expect(portal).to have_received(:upload_mod).with("test-mod", zip_path)
    end

    it "uploads a MOD with description" do
      command.call(file: zip_path.to_s, description: "Test description")

      expect(portal).to have_received(:upload_mod).with(
        "test-mod",
        zip_path,
        description: "Test description"
      )
    end

    it "uploads a MOD with category" do
      command.call(file: zip_path.to_s, category: "content")

      expect(portal).to have_received(:upload_mod).with(
        "test-mod",
        zip_path,
        category: "content"
      )
    end

    it "uploads a MOD with license" do
      command.call(file: zip_path.to_s, license: "MIT")

      expect(portal).to have_received(:upload_mod).with(
        "test-mod",
        zip_path,
        license: "MIT"
      )
    end

    it "uploads a MOD with source_url" do
      command.call(file: zip_path.to_s, source_url: "https://github.com/user/repo")

      expect(portal).to have_received(:upload_mod).with(
        "test-mod",
        zip_path,
        source_url: "https://github.com/user/repo"
      )
    end

    it "uploads a MOD with all metadata" do
      command.call(
        file: zip_path.to_s,
        description: "Full description",
        category: "utilities",
        license: "Apache-2.0",
        source_url: "https://example.com/repo"
      )

      expect(portal).to have_received(:upload_mod).with(
        "test-mod",
        zip_path,
        description: "Full description",
        category: "utilities",
        license: "Apache-2.0",
        source_url: "https://example.com/repo"
      )
    end

    it "subscribes and unsubscribes upload handler" do
      command.call(file: zip_path.to_s)

      expect(uploader).to have_received(:subscribe).with(kind_of(Factorix::Progress::UploadHandler))
      expect(uploader).to have_received(:unsubscribe).with(kind_of(Factorix::Progress::UploadHandler))
    end

    it "unsubscribes handler even when upload fails" do
      allow(portal).to receive(:upload_mod).and_raise(Factorix::HTTPClientError.new("Upload failed"))

      expect {
        command.call(file: zip_path.to_s)
      }.to raise_error(Factorix::HTTPClientError)

      expect(uploader).to have_received(:unsubscribe).with(kind_of(Factorix::Progress::UploadHandler))
    end

    context "with invalid file path" do
      it "raises error when file does not exist" do
        expect {
          command.call(file: "/nonexistent/file.zip")
        }.to raise_error(Factorix::InvalidArgumentError, /File not found/)
      end

      it "raises error when path is a directory" do
        expect {
          command.call(file: temp_dir.to_s)
        }.to raise_error(Factorix::InvalidArgumentError, /Not a file/)
      end

      it "raises error when file is not a zip" do
        txt_path = Pathname(temp_dir) / "file.txt"
        File.write(txt_path, "not a zip")

        expect {
          command.call(file: txt_path.to_s)
        }.to raise_error(Factorix::InvalidArgumentError, /must be a .zip file/)
      end
    end

    context "with invalid zip content" do
      it "raises error when info.json is missing" do
        bad_zip_path = Pathname(temp_dir) / "bad.zip"
        Zip::File.open(bad_zip_path, create: true) do |zipfile|
          zipfile.get_output_stream("readme.txt") {|f| f.write("no info.json") }
        end

        expect {
          command.call(file: bad_zip_path.to_s)
        }.to raise_error(Factorix::FileFormatError, /info.json not found/)
      end

      it "raises error when info.json is invalid" do
        invalid_zip_path = Pathname(temp_dir) / "invalid.zip"
        Zip::File.open(invalid_zip_path, create: true) do |zipfile|
          zipfile.get_output_stream("test-mod/info.json") {|f| f.write("{invalid json") }
        end

        expect {
          command.call(file: invalid_zip_path.to_s)
        }.to raise_error(Factorix::FileFormatError, /Invalid JSON/)
      end

      it "raises error when required fields are missing in info.json" do
        incomplete_zip_path = Pathname(temp_dir) / "incomplete.zip"
        incomplete_info = {
          "name" => "incomplete-mod",
          "version" => "1.0.0"
          # missing title and author
        }.to_json

        Zip::File.open(incomplete_zip_path, create: true) do |zipfile|
          zipfile.get_output_stream("test-mod/info.json") {|f| f.write(incomplete_info) }
        end

        expect {
          command.call(file: incomplete_zip_path.to_s)
        }.to raise_error(Factorix::FileFormatError, /Missing required fields/)
      end
    end
  end

  describe "#extract_mod_name" do
    it "extracts MOD name from zip file" do
      mod_name = command.__send__(:extract_mod_name, zip_path)
      expect(mod_name).to eq("test-mod")
    end
  end

  describe "#build_metadata" do
    it "returns empty hash when no metadata provided" do
      metadata = command.__send__(:build_metadata)
      expect(metadata).to eq({})
    end

    it "includes description when provided" do
      metadata = command.__send__(:build_metadata, description: "Test")
      expect(metadata).to eq({description: "Test"})
    end

    it "includes category when provided" do
      metadata = command.__send__(:build_metadata, category: "content")
      expect(metadata).to eq({category: "content"})
    end

    it "includes license when provided" do
      metadata = command.__send__(:build_metadata, license: "MIT")
      expect(metadata).to eq({license: "MIT"})
    end

    it "includes source_url when provided" do
      metadata = command.__send__(:build_metadata, source_url: "https://example.com")
      expect(metadata).to eq({source_url: "https://example.com"})
    end

    it "includes all metadata when provided" do
      metadata = command.__send__(
        :build_metadata,
        description: "Desc",
        category: "tweaks",
        license: "GPL-3.0",
        source_url: "https://repo.example.com"
      )

      expect(metadata).to eq({
        description: "Desc",
        category: "tweaks",
        license: "GPL-3.0",
        source_url: "https://repo.example.com"
      })
    end

    it "excludes nil values" do
      metadata = command.__send__(
        :build_metadata,
        description: "Desc",
        category: nil,
        license: "MIT",
        source_url: nil
      )

      expect(metadata).to eq({
        description: "Desc",
        license: "MIT"
      })
    end
  end
end
