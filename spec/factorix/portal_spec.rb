# frozen_string_literal: true

RSpec.describe Factorix::Portal do
  let(:mod_portal_api) { instance_double(Factorix::API::MODPortalAPI) }
  let(:mod_download_api) { instance_double(Factorix::API::MODDownloadAPI) }
  let(:mod_management_api) { instance_double(Factorix::API::MODManagementAPI) }
  let(:logger) { instance_double(Dry::Logger::Dispatcher, info: nil) }
  let(:portal) { Factorix::Portal.new(mod_portal_api:, mod_download_api:, mod_management_api:, logger:) }

  describe "#list_mods" do
    it "returns an array of MODInfo objects" do
      api_response = {
        pagination: {page: 1, page_count: 100, page_size: 2, count: 200},
        results: [
          {
            name: "mod-a",
            title: "MOD A",
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
            title: "MOD B",
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
      expect(mods.first).to be_a(Factorix::API::MODInfo)
      expect(mods.first.name).to eq("mod-a")
      expect(mods.first.title).to eq("MOD A")
      expect(mods.first.latest_release).to be_a(Factorix::API::Release)
    end
  end

  describe "#get_mod" do
    it "returns a MODInfo object without Detail" do
      api_response = {
        name: "test-mod",
        title: "Test MOD",
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

      expect(mod).to be_a(Factorix::API::MODInfo)
      expect(mod.name).to eq("test-mod")
      expect(mod.title).to eq("Test MOD")
      expect(mod.detail).to be_nil
      expect(mod.releases.size).to eq(1)
    end
  end

  describe "#get_mod_full" do
    it "returns a MODInfo object with Detail" do
      api_response = {
        name: "full-mod",
        title: "Full MOD",
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

      expect(mod).to be_a(Factorix::API::MODInfo)
      expect(mod.name).to eq("full-mod")
      expect(mod.detail).to be_a(Factorix::API::MODInfo::Detail)
      expect(mod.detail.changelog).to eq("1.0.0:\n- Initial release")
      expect(mod.detail.description).to eq("Full description")
    end
  end

  describe "#download_mod" do
    let(:release) do
      Factorix::API::Release[
        download_url: "/download/test-mod/1.0.0",
        file_name: "test-mod_1.0.0.zip",
        info_json: {},
        released_at: "2025-01-01T00:00:00Z",
        version: "1.0.0",
        sha1: "abc123"
      ]
    end

    it "downloads the MOD file to the specified path with SHA1 verification" do
      output_path = Pathname(Dir.tmpdir) / "test-mod.zip"
      allow(mod_download_api).to receive(:download).with("/download/test-mod/1.0.0", output_path, expected_sha1: "abc123", handler: nil)

      portal.download_mod(release, output_path)

      expect(mod_download_api).to have_received(:download).with("/download/test-mod/1.0.0", output_path, expected_sha1: "abc123", handler: nil)
    end
  end

  describe "#upload_mod" do
    let(:file_path) { Pathname("/tmp/test-mod_1.0.0.zip") }
    let(:upload_url) { URI("https://mods.factorio.com/upload/123") }

    context "when MOD does not exist (new MOD)" do
      before do
        allow(mod_portal_api).to receive(:get_mod).with("test-mod")
          .and_raise(Factorix::MODNotOnPortalError.new("MOD 'test-mod' not found on portal"))
        allow(mod_management_api).to receive(:init_publish).with("test-mod").and_return(upload_url)
        allow(mod_management_api).to receive(:finish_upload)
      end

      it "uses init_publish and includes metadata in finish_upload" do
        portal.upload_mod("test-mod", file_path, description: "Test", category: "content")

        expect(mod_management_api).to have_received(:init_publish).with("test-mod")
        expect(mod_management_api).to have_received(:finish_upload).with(
          "test-mod",
          upload_url,
          file_path,
          description: "Test",
          category: "content"
        )
      end

      it "works without metadata" do
        portal.upload_mod("test-mod", file_path)

        expect(mod_management_api).to have_received(:init_publish).with("test-mod")
        expect(mod_management_api).to have_received(:finish_upload).with("test-mod", upload_url, file_path)
      end
    end

    context "when MOD exists (update)" do
      let(:existing_mod_data) do
        {
          name: "test-mod",
          title: "Test MOD",
          owner: "test-user",
          summary: "Summary",
          downloads_count: 100,
          category: "content"
        }
      end

      before do
        allow(mod_portal_api).to receive(:get_mod).with("test-mod").and_return(existing_mod_data)
        allow(mod_management_api).to receive(:init_upload).with("test-mod").and_return(upload_url)
        allow(mod_management_api).to receive(:finish_upload)
        allow(mod_management_api).to receive(:edit_details)
      end

      it "uses init_upload and edit_details separately" do
        portal.upload_mod("test-mod", file_path, description: "Updated", license: "MIT")

        expect(mod_management_api).to have_received(:init_upload).with("test-mod")
        expect(mod_management_api).to have_received(:finish_upload).with("test-mod", upload_url, file_path)
        expect(mod_management_api).to have_received(:edit_details).with(
          "test-mod",
          description: "Updated",
          license: "MIT"
        )
      end

      it "skips edit_details when no metadata provided" do
        portal.upload_mod("test-mod", file_path)

        expect(mod_management_api).to have_received(:init_upload).with("test-mod")
        expect(mod_management_api).to have_received(:finish_upload).with("test-mod", upload_url, file_path)
        expect(mod_management_api).not_to have_received(:edit_details)
      end
    end

    it "re-raises non-404 errors" do
      allow(mod_portal_api).to receive(:get_mod).with("test-mod")
        .and_raise(Factorix::HTTPClientError.new("403 Forbidden"))

      expect {
        portal.upload_mod("test-mod", file_path)
      }.to raise_error(Factorix::HTTPClientError, /Forbidden/)
    end
  end

  describe "#edit_mod" do
    before do
      allow(mod_management_api).to receive(:edit_details)
    end

    it "calls edit_details with metadata" do
      portal.edit_mod("test-mod", description: "New description", category: "utilities")

      expect(mod_management_api).to have_received(:edit_details).with(
        "test-mod",
        description: "New description",
        category: "utilities"
      )
    end

    it "raises ArgumentError when no metadata provided" do
      expect {
        portal.edit_mod("test-mod")
      }.to raise_error(Factorix::MODSettingsError, /No metadata provided/)
    end

    it "accepts tags as array" do
      portal.edit_mod("test-mod", tags: %w[combat logistics])

      expect(mod_management_api).to have_received(:edit_details).with(
        "test-mod",
        tags: %w[combat logistics]
      )
    end
  end

  describe "#add_mod_image" do
    let(:image_file) { Pathname("/tmp/screenshot.png") }
    let(:upload_url) { URI("https://example.com/upload/789") }
    let(:response_data) do
      {
        "id" => "abc123def456",
        "url" => "https://assets-mod.factorio.com/assets/abc123def456.png",
        "thumbnail" => "https://assets-mod.factorio.com/assets/abc123def456.thumb.png"
      }
    end

    before do
      allow(mod_management_api).to receive_messages(init_image_upload: upload_url, finish_image_upload: response_data)
    end

    it "uploads image and returns Image object" do
      image = portal.add_mod_image("test-mod", image_file)

      expect(mod_management_api).to have_received(:init_image_upload).with("test-mod")
      expect(mod_management_api).to have_received(:finish_image_upload).with("test-mod", upload_url, image_file)
      expect(image).to be_a(Factorix::API::Image)
      expect(image.id).to eq("abc123def456")
      expect(image.url.to_s).to eq("https://assets-mod.factorio.com/assets/abc123def456.png")
      expect(image.thumbnail.to_s).to eq("https://assets-mod.factorio.com/assets/abc123def456.thumb.png")
    end

    it "re-raises HTTP errors" do
      allow(mod_management_api).to receive(:init_image_upload)
        .and_raise(Factorix::HTTPClientError.new("403 Forbidden"))

      expect {
        portal.add_mod_image("test-mod", image_file)
      }.to raise_error(Factorix::HTTPClientError, /Forbidden/)
    end
  end

  describe "#edit_mod_images" do
    before do
      allow(mod_management_api).to receive(:edit_images)
    end

    it "updates MOD's image list" do
      portal.edit_mod_images("test-mod", %w[abc123 def456 ghi789])

      expect(mod_management_api).to have_received(:edit_images).with(
        "test-mod",
        %w[abc123 def456 ghi789]
      )
    end

    it "accepts empty array" do
      portal.edit_mod_images("test-mod", [])

      expect(mod_management_api).to have_received(:edit_images).with("test-mod", [])
    end

    it "re-raises HTTP errors" do
      allow(mod_management_api).to receive(:edit_images)
        .and_raise(Factorix::HTTPClientError.new("400 Bad Request"))

      expect {
        portal.edit_mod_images("test-mod", %w[abc123])
      }.to raise_error(Factorix::HTTPClientError, /Bad Request/)
    end
  end
end
