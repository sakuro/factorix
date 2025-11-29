# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::DownloadSupport do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Factorix::CLI::Commands::DownloadSupport

      # Make private methods public for testing
      public :parse_mod_spec, :find_release, :find_compatible_release, :build_install_targets
    end
  end
  let(:instance) { test_class.new }

  describe "#parse_mod_spec" do
    it "parses MOD name without version as latest" do
      result = instance.parse_mod_spec("test-mod")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(:latest)
    end

    it "parses MOD name with specific version" do
      result = instance.parse_mod_spec("test-mod@1.2.3")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(Factorix::Types::MODVersion.from_string("1.2.3"))
    end

    it "parses MOD name with @latest as latest" do
      result = instance.parse_mod_spec("test-mod@latest")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(:latest)
    end

    it "parses MOD name with empty version as latest" do
      result = instance.parse_mod_spec("test-mod@")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(:latest)
    end

    it "returns a MOD object" do
      result = instance.parse_mod_spec("test-mod@1.0.0")
      expect(result[:mod]).to be_a(Factorix::MOD)
    end
  end

  describe "#find_release" do
    let(:release_v1) do
      Factorix::Types::Release.new(
        download_url: "/download/test-mod/v1",
        file_name: "test-mod_1.0.0.zip",
        info_json: {},
        released_at: "2024-01-01T00:00:00Z",
        version: "1.0.0",
        sha1: "abc123"
      )
    end

    let(:release_v2) do
      Factorix::Types::Release.new(
        download_url: "/download/test-mod/v2",
        file_name: "test-mod_2.0.0.zip",
        info_json: {},
        released_at: "2024-06-01T00:00:00Z",
        version: "2.0.0",
        sha1: "def456"
      )
    end

    let(:mod_info) do
      instance_double(
        Factorix::Types::MODInfo,
        releases: [release_v1, release_v2]
      )
    end

    context "when version is :latest" do
      it "returns the release with the latest released_at" do
        result = instance.find_release(mod_info, :latest)
        expect(result).to eq(release_v2)
      end
    end

    context "when version is a specific MODVersion" do
      it "returns the matching release" do
        version = Factorix::Types::MODVersion.from_string("1.0.0")
        result = instance.find_release(mod_info, version)
        expect(result).to eq(release_v1)
      end

      it "returns nil when no release matches" do
        version = Factorix::Types::MODVersion.from_string("3.0.0")
        result = instance.find_release(mod_info, version)
        expect(result).to be_nil
      end
    end
  end

  describe "#find_compatible_release" do
    let(:release_v1) do
      Factorix::Types::Release.new(
        download_url: "/download/test-mod/v1",
        file_name: "test-mod_1.0.0.zip",
        info_json: {},
        released_at: "2024-01-01T00:00:00Z",
        version: "1.0.0",
        sha1: "abc123"
      )
    end

    let(:release_v2) do
      Factorix::Types::Release.new(
        download_url: "/download/test-mod/v2",
        file_name: "test-mod_2.0.0.zip",
        info_json: {},
        released_at: "2024-06-01T00:00:00Z",
        version: "2.0.0",
        sha1: "def456"
      )
    end

    let(:release_v3) do
      Factorix::Types::Release.new(
        download_url: "/download/test-mod/v3",
        file_name: "test-mod_3.0.0.zip",
        info_json: {},
        released_at: "2024-12-01T00:00:00Z",
        version: "3.0.0",
        sha1: "ghi789"
      )
    end

    let(:mod_info) do
      instance_double(
        Factorix::Types::MODInfo,
        releases: [release_v1, release_v2, release_v3]
      )
    end

    context "when version_requirement is nil" do
      it "returns the latest release" do
        result = instance.find_compatible_release(mod_info, nil)
        expect(result).to eq(release_v3)
      end
    end

    context "when version_requirement is specified" do
      it "returns the latest compatible release" do
        requirement = Factorix::Dependency::MODVersionRequirement.new(
          operator: ">=",
          version: Factorix::Types::MODVersion.from_string("2.0.0")
        )
        result = instance.find_compatible_release(mod_info, requirement)
        expect(result).to eq(release_v3)
      end

      it "returns the matching release when only one matches" do
        requirement = Factorix::Dependency::MODVersionRequirement.new(
          operator: "=",
          version: Factorix::Types::MODVersion.from_string("1.0.0")
        )
        result = instance.find_compatible_release(mod_info, requirement)
        expect(result).to eq(release_v1)
      end

      it "returns nil when no release matches" do
        requirement = Factorix::Dependency::MODVersionRequirement.new(
          operator: ">=",
          version: Factorix::Types::MODVersion.from_string("4.0.0")
        )
        result = instance.find_compatible_release(mod_info, requirement)
        expect(result).to be_nil
      end
    end
  end

  describe "#build_install_targets" do
    let(:output_dir) { Pathname("/mods") }

    let(:release) do
      Factorix::Types::Release.new(
        download_url: "/download/test-mod/v1",
        file_name: "test-mod_1.0.0.zip",
        info_json: {},
        released_at: "2024-01-01T00:00:00Z",
        version: "1.0.0",
        sha1: "abc123"
      )
    end

    let(:mod_info) do
      instance_double(Factorix::Types::MODInfo, category: "utilities")
    end

    context "when info has :mod key" do
      let(:mod) { Factorix::MOD[name: "test-mod"] }
      let(:mod_infos) { [{mod:, mod_info:, release:}] }

      it "uses the provided MOD object" do
        result = instance.build_install_targets(mod_infos, output_dir)
        expect(result.first[:mod]).to eq(mod)
      end
    end

    context "when info has :mod_name key" do
      let(:mod_infos) { [{mod_name: "test-mod", mod_info:, release:}] }

      it "creates a MOD object from mod_name" do
        result = instance.build_install_targets(mod_infos, output_dir)
        expect(result.first[:mod].name).to eq("test-mod")
      end
    end

    it "builds correct target structure" do
      mod = Factorix::MOD[name: "test-mod"]
      mod_infos = [{mod:, mod_info:, release:}]

      result = instance.build_install_targets(mod_infos, output_dir)

      expect(result.first).to include(
        mod:,
        mod_info:,
        release:,
        output_path: Pathname("/mods/test-mod_1.0.0.zip"),
        category: "utilities"
      )
    end
  end
end
