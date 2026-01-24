# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Search do
  let(:data_dir) { Pathname(Dir.mktmpdir) }
  let(:runtime) { instance_double(Factorix::Runtime::Base, data_dir:) }
  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Search.new(runtime:) }

  let(:mod_info) do
    Factorix::API::MODInfo[
      name: "test-mod",
      title: "Test MOD",
      owner: "test-owner",
      summary: "A test MOD",
      downloads_count: 100,
      category: "utilities",
      score: 5.0,
      thumbnail: nil,
      latest_release: nil,
      releases: []
    ]
  end

  before do
    base_dir = data_dir / "base"
    base_dir.mkpath
    (base_dir / "info.json").write(JSON.generate(name: "base", version: "2.0.28", title: "Base", author: "Wube"))

    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)
  end

  after do
    FileUtils.remove_entry(data_dir)
  end

  describe "#call" do
    before do
      allow(portal).to receive(:list_mods).and_return([mod_info])
    end

    it "passes options to portal.list_mods" do
      run_command(command, %w[
        --hide-deprecated
        --page=2
        --page-size=50
        --sort=name
        --sort-order=asc
        --version=2.0
      ])

      expect(portal).to have_received(:list_mods).with(
        hide_deprecated: true,
        page: 2,
        page_size: 50,
        sort: "name",
        sort_order: "asc",
        version: "2.0"
      )
    end
  end

  describe "table output" do
    let(:mod_info_with_release) do
      Factorix::API::MODInfo[
        name: "test-mod",
        title: "Test MOD",
        owner: "test-owner",
        summary: "A test MOD",
        downloads_count: 100,
        category: "utilities",
        score: 5.0,
        thumbnail: nil,
        latest_release: {
          version: "1.2.3",
          download_url: "/download/test-mod/abc123",
          file_name: "test-mod_1.2.3.zip",
          info_json: {factorio_version: "2.0", dependencies: []},
          released_at: "2024-01-01T00:00:00Z",
          sha1: "abc123"
        },
        releases: []
      ]
    end

    before do
      allow(portal).to receive(:list_mods).and_return([mod_info_with_release])
    end

    it "displays latest_release version in LATEST column" do
      result = run_command(command)
      expect(result.stdout).to include("1.2.3")
    end
  end
end
