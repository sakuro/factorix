# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"

require_relative "../../../../../lib/factorix/cli/commands/mod/new"

RSpec.describe Factorix::CLI::Commands::Mod::New do
  let(:command) { described_class.new }

  describe "validation" do
    it "validates mod name length" do
      expect { command.call(mod_name: "ab") }.to raise_error(Factorix::CLIError, /must be longer than 3 characters/)
      expect { command.call(mod_name: "a" * 51) }.to raise_error(Factorix::CLIError, /shorter than 50 characters/)
    end

    it "validates mod name characters" do
      expect { command.call(mod_name: "invalid@name") }.to raise_error(Factorix::CLIError, /can only contain/)
      expect { command.call(mod_name: "invalid name") }.to raise_error(Factorix::CLIError, /can only contain/)
    end

    it "validates factorio version" do
      expect { command.call(mod_name: "test-mod", factorio_version: "1.1") }.to raise_error(Factorix::CLIError, /Only Factorio version 2.0/)
    end
  end

  describe "file creation" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:mod_name) { "test-mod" }

    after { FileUtils.rm_rf(temp_dir) }

    it "creates mod directory structure" do
      command.call(mod_name: mod_name, directory: temp_dir)

      mod_dir = File.join(temp_dir, mod_name)
      expect(Dir.exist?(mod_dir)).to be true

      # Check directory structure
      expect(Dir.exist?(File.join(mod_dir, "locale", "en"))).to be true

      # Check files
      expected_files = %w[
        info.json
        changelog.txt
        thumbnail.png
        settings.lua
        data.lua
        control.lua
        README.md
      ]

      expected_files.each do |file|
        expect(File.exist?(File.join(mod_dir, file))).to be true, "Expected #{file} to exist"
      end

      expect(File.exist?(File.join(mod_dir, "locale", "en", "#{mod_name}.cfg"))).to be true
    end

    it "creates info.json with correct content" do
      command.call(mod_name: mod_name, directory: temp_dir, author_name: "Test Author")

      info_path = File.join(temp_dir, mod_name, "info.json")
      content = JSON.parse(File.read(info_path))

      expect(content["name"]).to eq(mod_name)
      expect(content["version"]).to eq("0.0.1")
      expect(content["title"]).to eq("Test Mod")
      expect(content["author"]).to eq("Test Author")
      expect(content["factorio_version"]).to eq("2.0")
      expect(content["dependencies"]).to eq([])
    end

    it "capitalizes mod name correctly" do
      command.call(mod_name: "my-awesome_mod", directory: temp_dir)

      info_path = File.join(temp_dir, mod_name, "info.json")
      content = JSON.parse(File.read(info_path))

      expect(content["title"]).to eq("My Awesome Mod")
    end

    it "preserves case when mod name contains uppercase" do
      mod_name_with_caps = "MyAwesomeMod"
      command.call(mod_name: mod_name_with_caps, directory: temp_dir)

      info_path = File.join(temp_dir, mod_name_with_caps, "info.json")
      content = JSON.parse(File.read(info_path))

      expect(content["title"]).to eq("MyAwesomeMod")
    end
  end

  describe "error handling" do
    let(:temp_dir) { Dir.mktmpdir }
    let(:mod_name) { "test-mod" }

    after { FileUtils.rm_rf(temp_dir) }

    it "raises error when directory already exists" do
      FileUtils.mkdir_p(File.join(temp_dir, mod_name))

      expect {
        command.call(mod_name: mod_name, directory: temp_dir)
      }.to raise_error(Factorix::DirectoryExistsError, /Directory already exists/)
    end

    it "raises error when target directory does not exist" do
      non_existent_dir = File.join(temp_dir, "non-existent")

      expect {
        command.call(mod_name: mod_name, directory: non_existent_dir)
      }.to raise_error(Factorix::DirectoryNotFoundError, /Directory does not exist/)
    end
  end
end