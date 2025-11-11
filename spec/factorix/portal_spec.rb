# frozen_string_literal: true

RSpec.describe Factorix::Portal do
  let(:mod_portal_api) { instance_double(Factorix::API::MODPortalAPI) }
  let(:mod_download_api) { instance_double(Factorix::API::MODDownloadAPI) }
  let(:portal) { Factorix::Portal.new(mod_portal_api:, mod_download_api:) }

  describe "#list_mods" do
    it "returns an array of MODInfo objects" do
      api_response = {
        pagination: {page: 1, page_count: 100, page_size: 2, count: 200},
        results: [
          {
            name: "mod-a",
            title: "Mod A",
            owner: "user-a",
            summary: "Summary A",
            downloads_count: 100,
            category: "content",
            latest_release: {
              download_url: "/download/mod-a/1.0.0",
              file_name: "mod-a_1.0.0.zip",
              info_json: {},
              released_at: "2025-01-01T00:00:00Z",
              version: "1.0.0",
              sha1: "abc"
            }
          },
          {
            name: "mod-b",
            title: "Mod B",
            owner: "user-b",
            summary: "Summary B",
            downloads_count: 200,
            category: "utilities"
          }
        ]
      }
      allow(mod_portal_api).to receive(:get_mods).with(page_size: 2).and_return(api_response)

      mods = portal.list_mods(page_size: 2)

      expect(mods).to be_an(Array)
      expect(mods.size).to eq(2)
      expect(mods.first).to be_a(Factorix::Types::MODInfo)
      expect(mods.first.name).to eq("mod-a")
      expect(mods.first.title).to eq("Mod A")
      expect(mods.first.latest_release).to be_a(Factorix::Types::Release)
    end
  end

  describe "#get_mod" do
    it "returns a MODInfo object without Detail" do
      api_response = {
        name: "test-mod",
        title: "Test Mod",
        owner: "test-user",
        summary: "Test summary",
        downloads_count: 500,
        category: "tweaks",
        score: 0.9,
        releases: [
          {
            download_url: "/download/test-mod/1.0.0",
            file_name: "test-mod_1.0.0.zip",
            info_json: {},
            released_at: "2025-01-01T00:00:00Z",
            version: "1.0.0",
            sha1: "abc"
          }
        ]
      }
      allow(mod_portal_api).to receive(:get_mod).with("test-mod").and_return(api_response)

      mod = portal.get_mod("test-mod")

      expect(mod).to be_a(Factorix::Types::MODInfo)
      expect(mod.name).to eq("test-mod")
      expect(mod.title).to eq("Test Mod")
      expect(mod.detail).to be_nil
      expect(mod.releases.size).to eq(1)
    end
  end

  describe "#get_mod_full" do
    it "returns a MODInfo object with Detail" do
      api_response = {
        name: "full-mod",
        title: "Full Mod",
        owner: "full-user",
        summary: "Full summary",
        downloads_count: 1000,
        category: "overhaul",
        score: 0.95,
        releases: [],
        changelog: "1.0.0:\n- Initial release",
        created_at: "2024-01-01T00:00:00Z",
        updated_at: "2025-01-01T00:00:00Z",
        description: "Full description",
        homepage: "https://example.com",
        faq: "Q: How?\nA: Easy.",
        tags: %w[combat logistics]
      }
      allow(mod_portal_api).to receive(:get_mod_full).with("full-mod").and_return(api_response)

      mod = portal.get_mod_full("full-mod")

      expect(mod).to be_a(Factorix::Types::MODInfo)
      expect(mod.name).to eq("full-mod")
      expect(mod.detail).to be_a(Factorix::Types::MODInfo::Detail)
      expect(mod.detail.changelog).to eq("1.0.0:\n- Initial release")
      expect(mod.detail.description).to eq("Full description")
    end
  end

  describe "#download_mod" do
    let(:release) do
      Factorix::Types::Release[
        download_url: "/download/test-mod/1.0.0",
        file_name: "test-mod_1.0.0.zip",
        info_json: {},
        released_at: "2025-01-01T00:00:00Z",
        version: "1.0.0",
        sha1: "abc123"
      ]
    end

    it "downloads the mod file to the specified path" do
      output_path = Pathname(Dir.tmpdir) / "test-mod.zip"
      allow(mod_download_api).to receive(:download).with("/download/test-mod/1.0.0", output_path)

      portal.download_mod(release, output_path)

      expect(mod_download_api).to have_received(:download).with("/download/test-mod/1.0.0", output_path)
    end

    it "converts String path to Pathname" do
      output_path = "#{Dir.tmpdir}/test-mod.zip"
      expected_pathname = Pathname(output_path)
      allow(mod_download_api).to receive(:download).with("/download/test-mod/1.0.0", expected_pathname)

      portal.download_mod(release, output_path)

      expect(mod_download_api).to have_received(:download).with("/download/test-mod/1.0.0", expected_pathname)
    end
  end
end
