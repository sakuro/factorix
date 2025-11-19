# frozen_string_literal: true

require "tempfile"
require "zip"

RSpec.describe Factorix::InstalledMOD do
  include_context "with mock runtime"

  let(:temp_dir) { Pathname(Dir.mktmpdir) }
  let(:data_dir) { Pathname(Dir.mktmpdir) }

  before do
    allow(runtime).to receive_messages(mod_dir: temp_dir, data_dir:)
  end

  after do
    FileUtils.remove_entry(temp_dir) if temp_dir.exist?
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  describe ".all" do
    context "with empty mod directory" do
      it "returns empty array" do
        expect(Factorix::InstalledMOD.all).to eq([])
      end
    end

    context "with valid ZIP MOD" do
      let(:mod_name) { "test-mod" }
      let(:mod_version) { "1.0.0" }
      let(:zip_path) { temp_dir + "#{mod_name}_#{mod_version}.zip" }

      before do
        create_valid_zip_mod(zip_path, mod_name, mod_version)
      end

      it "finds the MOD" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(1)
        expect(mods.first.mod.name).to eq(mod_name)
        expect(mods.first.version.to_s).to eq(mod_version)
        expect(mods.first.form).to eq(Factorix::InstalledMOD::ZIP_FORM)
      end
    end

    context "with valid directory MOD (versioned)" do
      let(:mod_name) { "test-mod" }
      let(:mod_version) { "1.0.0" }
      let(:dir_path) { temp_dir + "#{mod_name}_#{mod_version}" }

      before do
        create_valid_directory_mod(dir_path, mod_name, mod_version)
      end

      it "finds the MOD" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(1)
        expect(mods.first.mod.name).to eq(mod_name)
        expect(mods.first.version.to_s).to eq(mod_version)
        expect(mods.first.form).to eq(Factorix::InstalledMOD::DIRECTORY_FORM)
      end
    end

    context "with valid directory MOD (unversioned)" do
      let(:mod_name) { "test-mod" }
      let(:mod_version) { "1.0.0" }
      let(:dir_path) { temp_dir + mod_name }

      before do
        create_valid_directory_mod(dir_path, mod_name, mod_version)
      end

      it "finds the MOD" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(1)
        expect(mods.first.mod.name).to eq(mod_name)
        expect(mods.first.version.to_s).to eq(mod_version)
        expect(mods.first.form).to eq(Factorix::InstalledMOD::DIRECTORY_FORM)
      end
    end

    context "with invalid ZIP (filename mismatch)" do
      let(:zip_path) { temp_dir + "wrong-name_1.0.0.zip" }

      before do
        create_valid_zip_mod(zip_path, "correct-name", "1.0.0")
      end

      it "skips the invalid MOD" do
        expect(Factorix::InstalledMOD.all).to be_empty
      end
    end

    context "with invalid directory (name mismatch)" do
      let(:dir_path) { temp_dir + "wrong-name_1.0.0" }

      before do
        create_valid_directory_mod(dir_path, "correct-name", "1.0.0")
      end

      it "skips the invalid MOD" do
        expect(Factorix::InstalledMOD.all).to be_empty
      end
    end

    context "with duplicate MODs (ZIP and directory, same version)" do
      let(:mod_name) { "test-mod" }
      let(:mod_version) { "1.0.0" }
      let(:zip_path) { temp_dir + "#{mod_name}_#{mod_version}.zip" }
      let(:dir_path) { temp_dir + "#{mod_name}_#{mod_version}" }

      before do
        create_valid_zip_mod(zip_path, mod_name, mod_version)
        create_valid_directory_mod(dir_path, mod_name, mod_version)
      end

      it "prefers directory over ZIP" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(1)
        expect(mods.first.form).to eq(Factorix::InstalledMOD::DIRECTORY_FORM)
      end
    end

    context "with multiple versions" do
      let(:mod_name) { "test-mod" }

      before do
        create_valid_zip_mod(temp_dir + "#{mod_name}_1.0.0.zip", mod_name, "1.0.0")
        create_valid_zip_mod(temp_dir + "#{mod_name}_2.0.0.zip", mod_name, "2.0.0")
        create_valid_zip_mod(temp_dir + "#{mod_name}_1.5.0.zip", mod_name, "1.5.0")
      end

      it "returns all versions sorted by version descending" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(3)
        expect(mods[0].version.to_s).to eq("2.0.0")
        expect(mods[1].version.to_s).to eq("1.5.0")
        expect(mods[2].version.to_s).to eq("1.0.0")
      end
    end

    context "with base MOD in data directory" do
      before do
        create_valid_directory_mod(data_dir + "base", "base", "1.1.0")
      end

      it "includes base MOD from data directory" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(1)
        expect(mods.first.mod.name).to eq("base")
        expect(mods.first.version.to_s).to eq("1.1.0")
      end
    end

    context "with expansion MODs in data directory" do
      before do
        create_valid_directory_mod(data_dir + "space-age", "space-age", "1.0.0")
        create_valid_directory_mod(data_dir + "quality", "quality", "1.0.0")
        create_valid_directory_mod(data_dir + "elevated-rails", "elevated-rails", "1.0.0")
      end

      it "includes all expansion MODs from data directory" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(3)
        mod_names = mods.map {|m| m.mod.name }
        expect(mod_names).to contain_exactly("space-age", "quality", "elevated-rails")
      end
    end

    context "with regular MOD in data directory" do
      before do
        create_valid_directory_mod(data_dir + "test-mod", "test-mod", "1.0.0")
      end

      it "excludes regular MOD from data directory" do
        expect(Factorix::InstalledMOD.all).to be_empty
      end
    end

    context "with MODs in both mod_dir and data_dir" do
      before do
        create_valid_directory_mod(data_dir + "base", "base", "1.1.0")
        create_valid_zip_mod(temp_dir + "test-mod_1.0.0.zip", "test-mod", "1.0.0")
        create_valid_directory_mod(temp_dir + "another-mod_2.0.0", "another-mod", "2.0.0")
      end

      it "finds MODs from both directories" do
        mods = Factorix::InstalledMOD.all
        expect(mods.size).to eq(3)
        mod_names = mods.map {|m| m.mod.name }
        expect(mod_names).to contain_exactly("base", "test-mod", "another-mod")
      end
    end
  end

  describe ".each" do
    before do
      create_valid_zip_mod(temp_dir + "mod1_1.0.0.zip", "mod1", "1.0.0")
      create_valid_directory_mod(temp_dir + "mod2_2.0.0", "mod2", "2.0.0")
    end

    it "yields each installed MOD when block given" do
      count = 0
      Factorix::InstalledMOD.each {|mod| count += 1 if mod.is_a?(Factorix::InstalledMOD) }
      expect(count).to eq(2)
    end

    it "returns Enumerator when no block given" do
      expect(Factorix::InstalledMOD.each).to be_a(Enumerator)
    end

    it "Enumerator yields all installed MODs" do
      enum = Factorix::InstalledMOD.each
      mod_names = enum.map {|mod| mod.mod.name }
      expect(mod_names).to contain_exactly("mod1", "mod2")
    end
  end

  describe "#<=>" do
    let(:mod1_v1) { build_installed_mod("test-mod", "1.0.0", :zip) }
    let(:mod1_v2) { build_installed_mod("test-mod", "2.0.0", :zip) }
    let(:mod1_v1_dir) { build_installed_mod("test-mod", "1.0.0", :directory) }
    let(:mod2_v1) { build_installed_mod("other-mod", "1.0.0", :zip) }

    it "sorts by version ascending" do
      expect(mod1_v1 <=> mod1_v2).to eq(-1)
      expect(mod1_v2 <=> mod1_v1).to eq(1)
    end

    it "prefers directory over ZIP for same version" do
      expect(mod1_v1_dir <=> mod1_v1).to eq(1)
      expect(mod1_v1 <=> mod1_v1_dir).to eq(-1)
    end

    it "returns nil for different MOD names" do
      expect(mod1_v1 <=> mod2_v1).to be_nil
    end
  end

  describe "#base?" do
    it "returns true for base MOD" do
      mod = build_installed_mod("base", "1.1.0", :directory)
      expect(mod.base?).to be true
    end

    it "returns false for non-base MOD" do
      mod = build_installed_mod("test-mod", "1.0.0", :directory)
      expect(mod.base?).to be false
    end

    it "returns false for expansion MOD" do
      mod = build_installed_mod("space-age", "1.0.0", :directory)
      expect(mod.base?).to be false
    end
  end

  describe "#expansion?" do
    it "returns true for space-age expansion" do
      mod = build_installed_mod("space-age", "1.0.0", :directory)
      expect(mod.expansion?).to be true
    end

    it "returns true for quality expansion" do
      mod = build_installed_mod("quality", "1.0.0", :directory)
      expect(mod.expansion?).to be true
    end

    it "returns true for elevated-rails expansion" do
      mod = build_installed_mod("elevated-rails", "1.0.0", :directory)
      expect(mod.expansion?).to be true
    end

    it "returns false for base MOD" do
      mod = build_installed_mod("base", "1.1.0", :directory)
      expect(mod.expansion?).to be false
    end

    it "returns false for regular MOD" do
      mod = build_installed_mod("test-mod", "1.0.0", :directory)
      expect(mod.expansion?).to be false
    end
  end

  describe ".from_zip" do
    let(:zip_path) { temp_dir + "test-mod_1.0.0.zip" }

    context "with valid ZIP" do
      before do
        create_valid_zip_mod(zip_path, "test-mod", "1.0.0")
      end

      it "creates InstalledMOD successfully" do
        mod = Factorix::InstalledMOD.from_zip(zip_path)
        expect(mod.mod.name).to eq("test-mod")
        expect(mod.version.to_s).to eq("1.0.0")
        expect(mod.form).to eq(Factorix::InstalledMOD::ZIP_FORM)
      end
    end

    context "with filename mismatch" do
      before do
        create_valid_zip_mod(zip_path, "different-name", "1.0.0")
      end

      it "raises ArgumentError" do
        expect {
          Factorix::InstalledMOD.from_zip(zip_path)
        }.to raise_error(ArgumentError, /Filename mismatch/)
      end
    end
  end

  describe ".from_directory" do
    context "with valid directory (versioned name)" do
      let(:dir_path) { temp_dir + "test-mod_1.0.0" }

      before do
        create_valid_directory_mod(dir_path, "test-mod", "1.0.0")
      end

      it "creates InstalledMOD successfully" do
        mod = Factorix::InstalledMOD.from_directory(dir_path)
        expect(mod.mod.name).to eq("test-mod")
        expect(mod.version.to_s).to eq("1.0.0")
        expect(mod.form).to eq(Factorix::InstalledMOD::DIRECTORY_FORM)
      end
    end

    context "with valid directory (unversioned name)" do
      let(:dir_path) { temp_dir + "test-mod" }

      before do
        create_valid_directory_mod(dir_path, "test-mod", "1.0.0")
      end

      it "creates InstalledMOD successfully" do
        mod = Factorix::InstalledMOD.from_directory(dir_path)
        expect(mod.mod.name).to eq("test-mod")
        expect(mod.version.to_s).to eq("1.0.0")
        expect(mod.form).to eq(Factorix::InstalledMOD::DIRECTORY_FORM)
      end
    end

    context "with missing info.json" do
      let(:dir_path) { temp_dir + "test-mod" }

      before do
        dir_path.mkpath
      end

      it "raises ArgumentError" do
        expect {
          Factorix::InstalledMOD.from_directory(dir_path)
        }.to raise_error(ArgumentError, /Missing info\.json/)
      end
    end

    context "with directory name mismatch" do
      let(:dir_path) { temp_dir + "test-mod_1.0.0" }

      before do
        create_valid_directory_mod(dir_path, "different-name", "1.0.0")
      end

      it "raises ArgumentError" do
        expect {
          Factorix::InstalledMOD.from_directory(dir_path)
        }.to raise_error(ArgumentError, /Directory name mismatch/)
      end
    end
  end

  describe "constants" do
    it "ZIP_FORM is :zip" do
      expect(Factorix::InstalledMOD::ZIP_FORM).to eq(:zip)
    end

    it "DIRECTORY_FORM is :directory" do
      expect(Factorix::InstalledMOD::DIRECTORY_FORM).to eq(:directory)
    end
  end

  # Helper methods for creating test fixtures

  def create_valid_zip_mod(zip_path, name, version)
    info_json = {
      name:,
      version:,
      title: "Test MOD",
      author: "Test Author",
      description: "Test description",
      factorio_version: "1.1"
    }.to_json

    Zip::File.open(zip_path, create: true) do |zipfile|
      zipfile.get_output_stream("#{name}_#{version}/info.json") {|f| f.write(info_json) }
    end
  end

  def create_valid_directory_mod(dir_path, name, version)
    dir_path.mkpath
    info_json = {
      name:,
      version:,
      title: "Test MOD",
      author: "Test Author",
      description: "Test description",
      factorio_version: "1.1"
    }.to_json

    (dir_path + "info.json").write(info_json)
  end

  def build_installed_mod(name, version, form)
    mod = Factorix::MOD[name:]
    mod_version = Factorix::Types::MODVersion.from_string(version)
    path = Pathname("/fake/path/#{name}_#{version}#{".zip" if form == :zip}")
    info = Factorix::Types::InfoJSON.from_hash(
      {
        "name" => name,
        "version" => version,
        "title" => "Test",
        "author" => "Test",
        "description" => "Test",
        "factorio_version" => "1.1"
      }
    )

    Factorix::InstalledMOD.new(mod:, version: mod_version, form:, path:, info:)
  end
end
