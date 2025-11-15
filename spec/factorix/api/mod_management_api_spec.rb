# frozen_string_literal: true

RSpec.describe Factorix::API::MODManagementAPI do
  let(:api_credential) { instance_double(Factorix::APICredential, api_key: "test_api_key") }
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:uploader) { instance_double(Factorix::Transfer::Uploader) }
  let(:api) { Factorix::API::MODManagementAPI.new(client:, uploader:) }

  before do
    # Stub api_credential in Application container for lazy loading
    allow(Factorix::Application).to receive(:[]).and_call_original
    allow(Factorix::Application).to receive(:[]).with(:api_credential).and_return(api_credential)
  end

  describe "#init_publish" do
    it "initializes new mod publication" do
      response = instance_double(Factorix::HTTP::Response, body: '{"upload_url":"https://example.com/upload/123"}')
      allow(client).to receive(:post).and_return(response)

      upload_url = api.init_publish("my-mod")

      expect(upload_url).to be_a(URI::HTTPS)
      expect(upload_url.to_s).to eq("https://example.com/upload/123")
      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/releases/init_publish")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/json")
        body = JSON.parse(options[:body])
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
    it "initializes upload to existing mod" do
      response = instance_double(Factorix::HTTP::Response, body: '{"upload_url":"https://example.com/upload/456"}')
      allow(client).to receive(:post).and_return(response)

      upload_url = api.init_upload("my-mod")

      expect(upload_url).to be_a(URI::HTTPS)
      expect(upload_url.to_s).to eq("https://example.com/upload/456")
      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/releases/init_upload")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/json")
        body = JSON.parse(options[:body])
        expect(body["mod"]).to eq("my-mod")
      end
    end

    it "raises HTTPClientError for 4xx errors" do
      allow(client).to receive(:post).and_raise(Factorix::HTTPClientError.new("404 Mod not found"))

      expect {
        api.init_upload("nonexistent-mod")
      }.to raise_error(Factorix::HTTPClientError, /not found/)
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
      api.finish_upload(upload_url, file_path)

      expect(uploader).to have_received(:upload).with(
        upload_url,
        file_path,
        fields: {}
      )
    end

    it "uploads file with metadata" do
      api.finish_upload(upload_url, file_path, description: "Test mod", category: "content")

      expect(uploader).to have_received(:upload).with(
        upload_url,
        file_path,
        fields: {"description" => "Test mod", "category" => "content"}
      )
    end

    it "accepts String file path" do
      api.finish_upload(upload_url, "/tmp/my-mod_1.0.0.zip")

      expect(uploader).to have_received(:upload)
    end

    it "rejects invalid metadata keys" do
      expect {
        api.finish_upload(upload_url, file_path, invalid_key: "value", another_bad: "test")
      }.to raise_error(ArgumentError, /Invalid metadata for finish_upload: invalid_key, another_bad/)
    end

    it "shows allowed keys in error message" do
      expect {
        api.finish_upload(upload_url, file_path, bad: "value")
      }.to raise_error(ArgumentError, /Allowed keys: description, category, license, source_url/)
    end

    it "accepts empty metadata" do
      expect {
        api.finish_upload(upload_url, file_path)
      }.not_to raise_error
    end
  end

  describe "#edit_details" do
    it "edits mod metadata" do
      response = instance_double(Factorix::HTTP::Response, body: '{"success":true}')
      allow(client).to receive(:post).and_return(response)

      api.edit_details("my-mod", description: "Updated description", category: "content")

      expect(client).to have_received(:post) do |uri, **options|
        expect(uri.to_s).to eq("https://mods.factorio.com/api/v2/mods/edit_details")
        expect(options[:headers]["Authorization"]).to eq("Bearer test_api_key")
        expect(options[:content_type]).to eq("application/json")
        body = JSON.parse(options[:body])
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
  end
end
