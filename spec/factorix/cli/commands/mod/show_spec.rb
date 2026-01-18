# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Show do
  let(:mod_dir) { Pathname(Dir.mktmpdir) }
  let(:mod_list_path) { Pathname(Dir.mktmpdir) / "mod-list.json" }
  let(:runtime) { instance_double(Factorix::Runtime::Base, mod_dir:, mod_list_path:) }
  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Show.new(runtime:, portal:) }

  let(:release_data) do
    {
      version: "1.2.3",
      download_url: "/download/test-mod/abc123",
      file_name: "test-mod_1.2.3.zip",
      info_json: {
        name: "test-mod",
        factorio_version: "2.0",
        dependencies: [
          "base >= 2.0",
          "? optional-dep >= 1.0",
          "! incompatible-mod"
        ]
      },
      released_at: "2024-01-01T00:00:00Z",
      sha1: "abc123"
    }
  end

  let(:mod_info) do
    Factorix::API::MODInfo.new(
      name: "test-mod",
      title: "Test MOD Title",
      owner: "test-author",
      summary: "A test MOD summary",
      downloads_count: 12_345,
      category: "utilities",
      score: 5.0,
      thumbnail: nil,
      latest_release: nil,
      releases: [release_data],
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-06-01T00:00:00Z",
      homepage: "https://example.com",
      source_url: "https://github.com/test/test-mod",
      license: {id: "default_mit", name: "mit", title: "MIT", description: "MIT", url: "https://opensource.org/licenses/MIT"}
    )
  end

  before do
    allow(Factorix::Container).to receive(:load_config)
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)
    allow(portal).to receive(:get_mod_full).with("test-mod").and_return(mod_info)
    allow(Factorix::InstalledMOD).to receive(:all).and_return([])

    # Stub MODList.load to return proper mock based on test needs
    default_mod_list = instance_double(Factorix::MODList)
    allow(default_mod_list).to receive_messages(exist?: false, enabled?: false)
    allow(Factorix::MODList).to receive(:load).and_return(default_mod_list)
  end

  after do
    FileUtils.remove_entry(mod_dir)
    FileUtils.remove_entry(mod_list_path.dirname)
  end

  describe "#call" do
    it "fetches MOD info from portal" do
      run_command(command, "test-mod")
      expect(portal).to have_received(:get_mod_full).with("test-mod")
    end

    it "raises BundledMODError for base MOD" do
      expect { run_command(command, "base") }.to raise_error(Factorix::BundledMODError, "Cannot show base MOD")
    end

    it "raises BundledMODError for expansion MODs" do
      %w[space-age quality elevated-rails].each do |expansion|
        expect { run_command(command, expansion) }.to raise_error(Factorix::BundledMODError, /Cannot show expansion MOD/)
      end
    end

    it "displays MOD title" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("Test MOD Title")
    end

    it "displays MOD summary" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("A test MOD summary")
    end

    it "displays version" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("1.2.3")
    end

    it "displays author" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("test-author")
    end

    it "displays category" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("Utilities")
    end

    it "displays downloads count" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("12345")
    end

    it "displays license from detail" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("MIT")
    end

    it "displays MOD portal link" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("https://mods.factorio.com/mod/test-mod")
    end

    it "displays source URL" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("https://github.com/test/test-mod")
    end

    it "displays required dependencies" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("base >= 2.0")
    end

    it "displays optional dependencies" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("optional-dep >= 1.0")
    end

    it "displays incompatibilities" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("incompatible-mod")
    end

    it "shows 'Not installed' for uninstalled MOD" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("Not installed")
    end
  end

  describe "installed MOD detection" do
    let(:installed_mod) do
      instance_double(
        Factorix::InstalledMOD,
        mod: Factorix::MOD["test-mod"],
        version: Factorix::MODVersion.from_string("1.0.0")
      )
    end

    before do
      enabled_mod_list = instance_double(Factorix::MODList)
      allow(enabled_mod_list).to receive_messages(exist?: true, enabled?: true)
      allow(Factorix::MODList).to receive(:load).and_return(enabled_mod_list)
      allow(Factorix::InstalledMOD).to receive(:all).and_return([installed_mod])
    end

    it "displays 'Enabled' for installed and enabled MOD" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("Enabled")
    end

    it "shows installed version with update available" do
      result = run_command(command, "test-mod")
      expect(result.stdout).to include("1.0.0 (update available)")
    end
  end
end
