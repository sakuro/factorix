# frozen_string_literal: true

RSpec.describe Factorix::API::MODManagementAPI do
  let(:api_credential) { instance_double(Factorix::APICredential, api_key: "test_api_key") }
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:uploader) { instance_double(Factorix::Transfer::Uploader) }
  let(:api) { Factorix::API::MODManagementAPI.new(client:, uploader:) }

  before do
    # Stub api_credential in Application container for lazy loading
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:api_credential).and_return(api_credential)
  end

  describe "#init_publish" do
    it "initializes new MOD publication" do
      response = instance_double(Factorix::HTTP::Response, body: '{"upload_url":"https://example.com/upload/123"}')
      allow(client).to receive(:post).and_return(response)

      upload_url = api.init_publish("my-mod")

      expect(upload_url).to be_a(URI::HTTPS)
      expect(upload_url.to_s).to eq("https://example.com/upload/123")
      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/init_publish")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/x-www-form-urlencoded")
        body = URI.decode_www_form(options[:body]).to_h
        expect(body["mod"]).to eq("my-mod")
      end
    end

    it "raises HTTPClientError for 4xx errors" do
      allow(client).to receive(:post).and_raise(Factorix::HTTPClientError.new("400 Mod already exists"))

      expect {
        api.init_publish("existing-mod")
      }.to raise_error(Factorix::HTTPClientError, /already exists/)
    end
  end

  describe "#init_upload" do
    it "initializes upload to existing MOD" do
      response = instance_double(Factorix::HTTP::Response, body: '{"upload_url":"https://example.com/upload/456"}')
      allow(client).to receive(:post).and_return(response)

      upload_url = api.init_upload("my-mod")

      expect(upload_url).to be_a(URI::HTTPS)
      expect(upload_url.to_s).to eq("https://example.com/upload/456")
      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/releases/init_upload")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/x-www-form-urlencoded")
        body = URI.decode_www_form(options[:body]).to_h
        expect(body["mod"]).to eq("my-mod")
      end
    end

    context "when MOD not found" do
      it "raises MODNotOnPortalError with api_message" do
        error = Factorix::HTTPNotFoundError.new("404 Not Found", api_message: "Unknown Mod")
        allow(client).to receive(:post).and_raise(error)

        expect {
          api.init_upload("nonexistent-mod")
        }.to raise_error(Factorix::MODNotOnPortalError, "Unknown Mod")
      end

      it "raises MODNotOnPortalError with fallback message when api_message is nil" do
        error = Factorix::HTTPNotFoundError.new("404 Not Found")
        allow(client).to receive(:post).and_raise(error)

        expect {
          api.init_upload("nonexistent-mod")
        }.to raise_error(Factorix::MODNotOnPortalError, "MOD 'nonexistent-mod' not found on portal")
      end
    end
  end

  describe "#finish_upload" do
    let(:upload_url) { URI("https://example.com/upload/123") }
    let(:file_path) { Pathname("/tmp/my-mod_1.0.0.zip") }

    before do
      allow(file_path).to receive(:is_a?).with(Pathname).and_return(true)
      allow(uploader).to receive(:upload)
    end

    it "uploads file without metadata" do
      api.finish_upload("my-mod", upload_url, file_path)

      expect(uploader).to have_received(:upload).with(
        upload_url,
        file_path,
        fields: {}
      )
    end

    it "uploads file with metadata" do
      api.finish_upload("my-mod", upload_url, file_path, description: "Test MOD", category: "content")

      expect(uploader).to have_received(:upload).with(
        upload_url,
        file_path,
        fields: {"description" => "Test MOD", "category" => "content"}
      )
    end

    it "rejects invalid metadata keys" do
      expect {
        api.finish_upload("my-mod", upload_url, file_path, invalid_key: "value", another_bad: "test")
      }.to raise_error(ArgumentError, /Invalid metadata for finish_upload: invalid_key, another_bad/)
    end

    it "shows allowed keys in error message" do
      expect {
        api.finish_upload("my-mod", upload_url, file_path, bad: "value")
      }.to raise_error(ArgumentError, /Allowed keys: description, category, license, source_url/)
    end

    it "accepts empty metadata" do
      expect {
        api.finish_upload("my-mod", upload_url, file_path)
      }.not_to raise_error
    end

    it "publishes mod.changed event" do
      events = []
      api.subscribe("mod.changed") {|event| events << event }

      api.finish_upload("my-mod", upload_url, file_path)

      expect(events.size).to eq(1)
      expect(events.first[:mod]).to eq("my-mod")
    end
  end

  describe "#edit_details" do
    it "edits MOD metadata" do
      response = instance_double(Factorix::HTTP::Response, body: '{"success":true}')
      allow(client).to receive(:post).and_return(response)

      api.edit_details("my-mod", description: "Updated description", category: "content")

      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/edit_details")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/x-www-form-urlencoded")
        body = URI.decode_www_form(options[:body]).to_h
        expect(body["mod"]).to eq("my-mod")
        expect(body["description"]).to eq("Updated description")
        expect(body["category"]).to eq("content")
      end
    end

    it "raises HTTPClientError for 4xx errors" do
      allow(client).to receive(:post).and_raise(Factorix::HTTPClientError.new("403 Forbidden"))

      expect {
        api.edit_details("my-mod", description: "test")
      }.to raise_error(Factorix::HTTPClientError, /Forbidden/)
    end

    it "rejects invalid metadata keys" do
      expect {
        api.edit_details("my-mod", invalid_field: "value")
      }.to raise_error(ArgumentError, /Invalid metadata for edit_details: invalid_field/)
    end

    it "shows allowed keys in error message" do
      expect {
        api.edit_details("my-mod", bad: "value")
      }.to raise_error(ArgumentError, /Allowed keys:.*description.*summary.*title/)
    end

    it "accepts all valid edit fields" do
      response = instance_double(Factorix::HTTP::Response, body: '{"success":true}')
      allow(client).to receive(:post).and_return(response)

      expect {
        api.edit_details(
          "my-mod",
          description: "desc",
          summary: "sum",
          title: "title",
          category: "content",
          tags: "tag1,tag2",
          license: "MIT",
          homepage: "https://example.com",
          source_url: "https://github.com/user/repo",
          faq: "FAQ text",
          deprecated: true
        )
      }.not_to raise_error
    end

    it "publishes mod.changed event" do
      response = instance_double(Factorix::HTTP::Response, body: '{"success":true}')
      allow(client).to receive(:post).and_return(response)

      events = []
      api.subscribe("mod.changed") {|event| events << event }

      api.edit_details("my-mod", description: "Updated description")

      expect(events.size).to eq(1)
      expect(events.first[:mod]).to eq("my-mod")
    end
  end

  describe "#init_image_upload" do
    it "initializes image upload" do
      response = instance_double(Factorix::HTTP::Response, body: '{"upload_url":"https://example.com/upload/789"}')
      allow(client).to receive(:post).and_return(response)

      upload_url = api.init_image_upload("my-mod")

      expect(upload_url).to be_a(URI::HTTPS)
      expect(upload_url.to_s).to eq("https://example.com/upload/789")
      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/images/add")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/x-www-form-urlencoded")
        body = URI.decode_www_form(options[:body]).to_h
        expect(body["mod"]).to eq("my-mod")
      end
    end

    it "raises HTTPClientError for 4xx errors" do
      allow(client).to receive(:post).and_raise(Factorix::HTTPClientError.new("403 Forbidden"))

      expect {
        api.init_image_upload("my-mod")
      }.to raise_error(Factorix::HTTPClientError, /Forbidden/)
    end
  end

  describe "#finish_image_upload" do
    let(:upload_url) { URI("https://example.com/upload/789") }
    let(:image_file) { Pathname("/tmp/screenshot.png") }
    let(:response_data) do
      {
        "id" => "abc123def456",
        "url" => "https://assets-mod.factorio.com/assets/abc123def456.png",
        "thumbnail" => "https://assets-mod.factorio.com/assets/abc123def456.thumb.png"
      }
    end

    before do
      allow(image_file).to receive(:is_a?).with(Pathname).and_return(true)
    end

    it "uploads image and returns parsed response" do
      response = instance_double(Factorix::HTTP::Response, body: JSON.generate(response_data))
      allow(uploader).to receive(:upload).and_return(response)

      result = api.finish_image_upload("my-mod", upload_url, image_file)

      expect(uploader).to have_received(:upload).with(upload_url, image_file, field_name: "image")
      expect(result).to eq(response_data)
    end

    it "raises HTTPError for invalid JSON response" do
      response = instance_double(Factorix::HTTP::Response, body: "invalid json")
      allow(uploader).to receive(:upload).and_return(response)

      expect {
        api.finish_image_upload("my-mod", upload_url, image_file)
      }.to raise_error(Factorix::HTTPError, /Invalid JSON response/)
    end

    it "publishes mod.changed event" do
      response = instance_double(Factorix::HTTP::Response, body: JSON.generate(response_data))
      allow(uploader).to receive(:upload).and_return(response)

      events = []
      api.subscribe("mod.changed") {|event| events << event }

      api.finish_image_upload("my-mod", upload_url, image_file)

      expect(events.size).to eq(1)
      expect(events.first[:mod]).to eq("my-mod")
    end
  end

  describe "#edit_images" do
    it "updates MOD's image list" do
      response = instance_double(Factorix::HTTP::Response, body: '{"success":true}')
      allow(client).to receive(:post).and_return(response)

      api.edit_images("my-mod", %w[abc123 def456 ghi789])

      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/images/edit")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/x-www-form-urlencoded")
        body = URI.decode_www_form(options[:body]).to_h
        expect(body["mod"]).to eq("my-mod")
        expect(body["images"]).to eq("abc123,def456,ghi789")
      end
    end

    it "accepts empty array" do
      response = instance_double(Factorix::HTTP::Response, body: '{"success":true}')
      allow(client).to receive(:post).and_return(response)

      api.edit_images("my-mod", [])

      expect(client).to have_received(:post) do |_uri, **options|
        body = URI.decode_www_form(options[:body]).to_h
        expect(body["images"]).to eq("")
      end
    end

    it "raises ArgumentError if image_ids is not an array" do
      expect {
        api.edit_images("my-mod", "abc123,def456")
      }.to raise_error(ArgumentError, /image_ids must be an array/)
    end

    it "raises HTTPClientError for 4xx errors" do
      allow(client).to receive(:post).and_raise(Factorix::HTTPClientError.new("400 Bad Request"))

      expect {
        api.edit_images("my-mod", %w[abc123])
      }.to raise_error(Factorix::HTTPClientError, /Bad Request/)
    end

    it "publishes mod.changed event" do
      response = instance_double(Factorix::HTTP::Response, body: '{"success":true}')
      allow(client).to receive(:post).and_return(response)

      events = []
      api.subscribe("mod.changed") {|event| events << event }

      api.edit_images("my-mod", %w[abc123 def456])

      expect(events.size).to eq(1)
      expect(events.first[:mod]).to eq("my-mod")
    end
  end
end
