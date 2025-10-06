# frozen_string_literal: true

require "json"
require "pathname"
require "spec_helper"
require "tmpdir"

RSpec.describe Factorix::CLI::Commands::Mod::New do
  subject(:command) { Factorix::CLI::Commands::Mod::New.new }

  let(:mod_name) { "test-mod" }
  let(:author_name) { "Test Author" }
  let(:factorio_version) { "2.0" }

  describe "#call" do
    around do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = Pathname(tmpdir)
        example.run
      end
    end

    context "with valid arguments" do
      it "creates MOD directory structure" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:)

        mod_dir = @tmpdir / mod_name
        expect(mod_dir).to exist

        # Check directory structure
        expect(mod_dir / "locale" / "en").to exist
        expect(mod_dir / "locale" / "en" / "#{mod_name}.cfg").to exist
        expect(mod_dir / "info.json").to exist
        expect(mod_dir / "changelog.txt").to exist
        expect(mod_dir / "thumbnail.png").to exist
        expect(mod_dir / "settings.lua").to exist
        expect(mod_dir / "data.lua").to exist
        expect(mod_dir / "control.lua").to exist
        expect(mod_dir / "README.md").to exist
      end

      it "generates correct info.json content" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:, factorio_version:)

        info_json = @tmpdir / mod_name / "info.json"
        content = JSON.parse(info_json.read)

        expect(content["name"]).to eq(mod_name)
        expect(content["version"]).to eq("0.0.1")
        expect(content["title"]).to eq("Test mod")
        expect(content["author"]).to eq(author_name)
        expect(content["factorio_version"]).to eq(factorio_version)
        expect(content["dependencies"]).to eq(["base >= 2.0"])
      end

      it "generates correct locale file content" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:)

        locale_file = @tmpdir / mod_name / "locale" / "en" / "#{mod_name}.cfg"
        content = locale_file.read

        expect(content).to include("[mod-name]")
        expect(content).to include("#{mod_name}=Test mod")
        expect(content).to include("[mod-description]")
      end

      it "generates correct changelog content" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:)

        changelog = @tmpdir / mod_name / "changelog.txt"
        content = changelog.read

        expect(content).to include("Version: 0.0.1")
        expect(content).to include("Date: #{Time.now.strftime("%Y-%m-%d")}")
        expect(content).to include("- Initial release")
      end

      it "generates correct README content" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:)

        readme = @tmpdir / mod_name / "README.md"
        content = readme.read

        expect(content.strip).to eq("# #{mod_name}")
      end

      it "creates empty Lua files" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:)

        mod_dir = @tmpdir / mod_name
        %w[settings.lua data.lua control.lua].each do |lua_file|
          file_path = mod_dir / lua_file
          expect(file_path).to exist
          expect(file_path.read).to be_empty
        end
      end

      it "initializes git repository when git option is true" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:, git: true)

        mod_dir = @tmpdir / mod_name
        expect(mod_dir / ".git").to exist

        # Check that files are staged
        Dir.chdir(mod_dir) do
          staged_files = %x(git diff --cached --name-only).split("\n")
          expect(staged_files).to include("info.json")
          expect(staged_files).to include("README.md")
        end
      end

      it "does not initialize git repository when git option is false" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:, git: false)

        mod_dir = @tmpdir / mod_name
        expect(mod_dir / ".git").not_to exist
      end

      it "raises error when git command fails" do
        # Mock system to simulate git failure
        allow(command).to receive(:system).and_return(false)

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name:, git: true)
        }.to raise_error(Factorix::CLIError, /Git repository initialization failed/)
      end

      it "raises FileSystemError when thumbnail copy fails" do
        # Mock TemplateRenderer copy_file to simulate file system error for thumbnail
        mock_renderer = instance_double(Factorix::TemplateRenderer)
        allow(Factorix::TemplateRenderer).to receive(:new).and_return(mock_renderer)
        allow(mock_renderer).to receive(:render)
        allow(mock_renderer).to receive(:copy_file).with("thumbnail.png", "thumbnail.png").and_raise(
          Factorix::FileSystemError, "Not enough disk space to copy thumbnail image"
        )

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name:)
        }.to raise_error(Factorix::FileSystemError, /Not enough disk space/)
      end

      it "raises DirectoryNotWritableError when lua file creation fails due to permissions" do
        # Mock TemplateRenderer copy_file to simulate permission error for Lua files
        mock_renderer = instance_double(Factorix::TemplateRenderer)
        allow(Factorix::TemplateRenderer).to receive(:new).and_return(mock_renderer)
        allow(mock_renderer).to receive(:render)
        allow(mock_renderer).to receive(:copy_file).with("thumbnail.png", "thumbnail.png")
        allow(mock_renderer).to receive(:copy_file).with("settings.lua", "settings.lua").and_raise(
          Factorix::DirectoryNotWritableError, "Permission denied: cannot write settings.lua"
        )

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name:)
        }.to raise_error(Factorix::DirectoryNotWritableError, /Permission denied.*settings\.lua/)
      end

      it "cleans up partially created directory when creation fails" do
        mod_dir = @tmpdir / mod_name

        # Mock create_mod_structure to fail after directory creation
        allow(command).to receive(:create_mod_structure).and_raise(
          Factorix::FileSystemError, "Simulated failure during file creation"
        )

        # Verify directory doesn't exist after cleanup
        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name:)
        }.to raise_error(Factorix::FileSystemError, /Simulated failure/)

        expect(mod_dir).not_to exist
      end

      it "warns but continues if cleanup fails" do
        # Mock create_mod_structure to fail
        allow(command).to receive(:create_mod_structure).and_raise(
          Factorix::FileSystemError, "Creation failure"
        )

        # Mock cleanup to fail
        allow(command).to receive(:cleanup_partial_directory) do |dir|
          warn "Warning: Failed to clean up partial directory #{dir}: Permission denied"
          # Don't actually clean up to simulate cleanup failure
        end

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name:)
        }.to raise_error(Factorix::FileSystemError, /Creation failure/)
      end

      it "raises TemplateError when template rendering fails" do
        # Create a mock renderer that fails
        mock_renderer = instance_double(Factorix::TemplateRenderer)
        allow(Factorix::TemplateRenderer).to receive(:new).and_return(mock_renderer)
        allow(mock_renderer).to receive(:render).and_raise(
          Factorix::TemplateError, "Template syntax error in info.json.erb: undefined method 'invalid_method'"
        )

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name:)
        }.to raise_error(Factorix::TemplateError, /Template syntax error.*info\.json\.erb/)
      end

      it "raises FileSystemError when template file reading fails" do
        # Create a mock renderer that fails
        mock_renderer = instance_double(Factorix::TemplateRenderer)
        allow(Factorix::TemplateRenderer).to receive(:new).and_return(mock_renderer)
        allow(mock_renderer).to receive(:render).and_raise(
          Factorix::FileSystemError, "I/O error reading template info.json.erb"
        )

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name:)
        }.to raise_error(Factorix::FileSystemError, %r{I/O error reading template})
      end

      it "raises DirectoryNotWritableError when directory creation fails due to permissions" do
        # Create a read-only directory to simulate permission error
        readonly_dir = @tmpdir / "readonly"
        readonly_dir.mkdir
        readonly_dir.chmod(0444) # Read-only

        expect {
          command.call(mod_name:, directory: readonly_dir.to_s, author_name:)
        }.to raise_error(Factorix::DirectoryNotWritableError, /Permission denied.*cannot create directory/)

        # Cleanup
        readonly_dir.chmod(0755)
      end
    end

    context "with default values" do
      it "uses default factorio version" do
        command.call(mod_name:, directory: @tmpdir.to_s, author_name:)

        info_json = @tmpdir / mod_name / "info.json"
        content = JSON.parse(info_json.read)
        expect(content["factorio_version"]).to eq("2.0")
      end

      it "uses login name as author when not specified" do
        allow(ENV).to receive(:[]).with("USER").and_return("testuser")
        command.call(mod_name:, directory: @tmpdir.to_s)

        info_json = @tmpdir / mod_name / "info.json"
        content = JSON.parse(info_json.read)
        expect(content["author"]).to eq("testuser")
      end
    end

    context "with invalid arguments" do
      it "raises ValidationError for short MOD name" do
        expect {
          command.call(mod_name: "ab", directory: @tmpdir.to_s)
        }.to raise_error(Factorix::ValidationError, /must be between 4 and 49 characters long/)
      end

      it "raises ValidationError for long MOD name" do
        long_name = "a" * 51
        expect {
          command.call(mod_name: long_name, directory: @tmpdir.to_s)
        }.to raise_error(Factorix::ValidationError, /must be between 4 and 49 characters long/)
      end

      it "raises ValidationError for invalid characters in MOD name" do
        expect {
          command.call(mod_name: "test@mod..test/mod", directory: @tmpdir.to_s)
        }.to raise_error(Factorix::ValidationError, /can only contain alphanumeric characters/)
      end

      it "raises ValidationError for invalid factorio version" do
        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, factorio_version: "1.1")
        }.to raise_error(Factorix::ValidationError, /Only Factorio version '2.0' is currently supported/)
      end

      it "raises ValidationError when no author name is available" do
        allow(ENV).to receive(:[]).with("USER").and_return(nil)
        allow(ENV).to receive(:[]).with("USERNAME").and_return(nil)

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s)
        }.to raise_error(Factorix::ValidationError, /Author name is required/)
      end

      it "raises ValidationError for empty author name" do
        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name: "")
        }.to raise_error(Factorix::ValidationError, /Author name is required/)
      end

      it "raises ValidationError for whitespace-only author name" do
        expect {
          command.call(mod_name:, directory: @tmpdir.to_s, author_name: "   ")
        }.to raise_error(Factorix::ValidationError, /Author name is required/)
      end

      it "raises DirectoryNotFoundError for non-existent directory" do
        expect {
          command.call(mod_name:, directory: "/non/existent/path")
        }.to raise_error(Factorix::DirectoryNotFoundError, /Target directory does not exist/)
      end

      it "raises DirectoryNotFoundError when directory is actually a file" do
        file_path = @tmpdir / "not_a_directory"
        file_path.write("test content")

        expect {
          command.call(mod_name:, directory: file_path.to_s)
        }.to raise_error(Factorix::DirectoryNotFoundError, /Target path is not a directory/)
      end

      it "raises FileExistsError when MOD directory already exists" do
        existing_dir = @tmpdir / mod_name
        existing_dir.mkpath

        expect {
          command.call(mod_name:, directory: @tmpdir.to_s)
        }.to raise_error(Factorix::FileExistsError, /Directory already exists/)
      end

      # NOTE: Race condition protection is handled by using mkdir (not mkpath)
      # in create_mod_structure, which atomically fails if directory exists
    end

    context "with capitalized MOD names" do
      it "preserves capitalization when uppercase letters are present" do
        capitalized_name = "MyTestMod"
        command.call(mod_name: capitalized_name, directory: @tmpdir.to_s, author_name:)

        info_json = @tmpdir / capitalized_name / "info.json"
        content = JSON.parse(info_json.read)
        expect(content["title"]).to eq(capitalized_name)
      end

      it "capitalizes and converts separators when no uppercase letters" do
        command.call(mod_name: "my-test_mod", directory: @tmpdir.to_s, author_name:)

        info_json = @tmpdir / "my-test_mod" / "info.json"
        content = JSON.parse(info_json.read)
        expect(content["title"]).to eq("My test mod")
      end
    end
  end
end
