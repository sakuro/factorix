# frozen_string_literal: true

RSpec.describe Factorix::API::MODListAPI do
  let(:api_cache) { instance_double(Factorix::Cache::FileSystem) }
  let(:api) { Factorix::API::MODListAPI.new(api_cache:) }

  before do
    allow(api_cache).to receive(:key_for).and_return("cache_key")
  end

  describe "#get_mods" do
    let(:response_body) { '{"results": [], "pagination": {}}' }
    let(:parsed_response) { {results: [], pagination: {}} }

    context "when cache miss" do
      before do
        allow(api_cache).to receive(:read).and_return(nil)
        allow(api_cache).to receive(:store)
        stub_request(:get, "https://mods.factorio.com/api/mods")
          .to_return(status: 200, body: response_body)
      end

      it "fetches from API and returns parsed JSON" do
        result = api.get_mods
        expect(result).to eq(parsed_response)
      end

      it "stores response in cache" do
        api.get_mods
        expect(api_cache).to have_received(:store).with("cache_key", kind_of(String))
      end
    end

    context "when cache hit" do
      before do
        allow(api_cache).to receive(:read).with("cache_key", encoding: "UTF-8").and_return(response_body)
      end

      it "returns cached data without making HTTP request" do
        result = api.get_mods
        expect(result).to eq(parsed_response)
        expect(a_request(:get, "https://mods.factorio.com/api/mods")).not_to have_been_made
      end
    end

    context "with query parameters" do
      before do
        allow(api_cache).to receive(:read).and_return(nil)
        allow(api_cache).to receive(:store)
        stub_request(:get, "https://mods.factorio.com/api/mods?page=2&page_size=10")
          .to_return(status: 200, body: response_body)
      end

      it "includes query parameters in request" do
        api.get_mods(page: 2, page_size: 10)
        expect(a_request(:get, "https://mods.factorio.com/api/mods?page=2&page_size=10")).to have_been_made
      end

      it "normalizes parameter order for cache efficiency" do
        # Different key order should result in same URL
        api.get_mods(page_size: 10, page: 2)
        expect(a_request(:get, "https://mods.factorio.com/api/mods?page=2&page_size=10")).to have_been_made
      end
    end
  end

  describe "#get_mod" do
    let(:response_body) { '{"name": "example-mod", "releases": []}' }
    let(:parsed_response) { {name: "example-mod", releases: []} }

    context "when cache miss" do
      before do
        allow(api_cache).to receive(:read).and_return(nil)
        allow(api_cache).to receive(:store)
        stub_request(:get, "https://mods.factorio.com/api/mods/example-mod")
          .to_return(status: 200, body: response_body)
      end

      it "fetches mod info from API" do
        result = api.get_mod("example-mod")
        expect(result).to eq(parsed_response)
      end

      it "stores response in cache" do
        api.get_mod("example-mod")
        expect(api_cache).to have_received(:store)
      end
    end

    context "when cache hit" do
      before do
        allow(api_cache).to receive(:read).with("cache_key", encoding: "UTF-8").and_return(response_body)
      end

      it "returns cached data" do
        result = api.get_mod("example-mod")
        expect(result).to eq(parsed_response)
        expect(a_request(:get, "https://mods.factorio.com/api/mods/example-mod")).not_to have_been_made
      end
    end
  end

  describe "#get_mod_full" do
    let(:response_body) { '{"name": "example-mod", "changelog": "...", "releases": []}' }
    let(:parsed_response) { {name: "example-mod", changelog: "...", releases: []} }

    context "when cache miss" do
      before do
        allow(api_cache).to receive(:read).and_return(nil)
        allow(api_cache).to receive(:store)
        stub_request(:get, "https://mods.factorio.com/api/mods/example-mod/full")
          .to_return(status: 200, body: response_body)
      end

      it "fetches full mod info from API" do
        result = api.get_mod_full("example-mod")
        expect(result).to eq(parsed_response)
      end

      it "stores response in cache" do
        api.get_mod_full("example-mod")
        expect(api_cache).to have_received(:store)
      end
    end

    context "when cache hit" do
      before do
        allow(api_cache).to receive(:read).with("cache_key", encoding: "UTF-8").and_return(response_body)
      end

      it "returns cached data" do
        result = api.get_mod_full("example-mod")
        expect(result).to eq(parsed_response)
        expect(a_request(:get, "https://mods.factorio.com/api/mods/example-mod/full")).not_to have_been_made
      end
    end
  end

  describe "error handling" do
    before do
      allow(api_cache).to receive(:read).and_return(nil)
      allow(api_cache).to receive(:store)
    end

    context "when API returns 404" do
      before do
        stub_request(:get, "https://mods.factorio.com/api/mods/nonexistent")
          .to_return(status: [404, "Not Found"], body: "Not Found")
      end

      it "raises HTTPClientError" do
        expect { api.get_mod("nonexistent") }.to raise_error(Factorix::HTTPClientError, "404 Not Found")
      end
    end

    context "when API returns 500" do
      before do
        stub_request(:get, "https://mods.factorio.com/api/mods")
          .to_return(status: [500, "Internal Server Error"], body: "Internal Server Error")
      end

      it "raises HTTPServerError" do
        expect { api.get_mods }.to raise_error(Factorix::HTTPServerError, "500 Internal Server Error")
      end
    end
  end
end
