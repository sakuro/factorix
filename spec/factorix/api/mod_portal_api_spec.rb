# frozen_string_literal: true

RSpec.describe Factorix::API::MODPortalAPI do
  let(:client) { instance_double(Factorix::HTTP::Client) }
  let(:cache) { instance_double(Factorix::Cache::FileSystem) }
  let(:api) { Factorix::API::MODPortalAPI.new(cache:, client:) }

  before do
    allow(cache).to receive(:key_for).and_return("cache_key")
  end

  describe "#get_mods" do
    let(:response_body) { '{"results": [], "pagination": {}}' }
    let(:parsed_response) { {results: [], pagination: {}} }

    context "when cache miss" do
      before do
        allow(cache).to receive(:read).and_return(nil)
        allow(cache).to receive(:store)
        response = instance_double(Factorix::HTTP::Response, code: 200, body: response_body)
        allow(client).to receive(:get).and_return(response)
      end

      it "fetches from API and returns parsed JSON" do
        result = api.get_mods
        expect(result).to eq(parsed_response)
      end

      it "stores response in cache" do
        api.get_mods
        expect(cache).to have_received(:store).with("cache_key", kind_of(String))
      end
    end

    context "when cache hit" do
      before do
        allow(cache).to receive(:read).with("cache_key", encoding: "UTF-8").and_return(response_body)
      end

      it "returns cached data without making HTTP request" do
        result = api.get_mods
        expect(result).to eq(parsed_response)
        expect(a_request(:get, "https://mods.factorio.com/api/mods")).not_to have_been_made
      end
    end

    context "with query parameters" do
      before do
        allow(cache).to receive(:read).and_return(nil)
        allow(cache).to receive(:store)
        response = instance_double(Factorix::HTTP::Response, code: 200, body: response_body)
        allow(client).to receive(:get).and_return(response)
      end

      it "includes query parameters in request" do
        api.get_mods(page: 2, page_size: 10)
        expect(client).to have_received(:get).with(URI("https://mods.factorio.com/api/mods?page=2&page_size=10"))
      end

      it "normalizes parameter order for cache efficiency" do
        # Different key order should result in same URL
        api.get_mods(page_size: 10, page: 2)
        expect(client).to have_received(:get).with(URI("https://mods.factorio.com/api/mods?page=2&page_size=10"))
      end
    end
  end

  describe "#get_mod" do
    let(:response_body) { '{"name": "example-mod", "releases": []}' }
    let(:parsed_response) { {name: "example-mod", releases: []} }

    context "when cache miss" do
      before do
        allow(cache).to receive(:read).and_return(nil)
        allow(cache).to receive(:store)
        response = instance_double(Factorix::HTTP::Response, code: 200, body: response_body)
        allow(client).to receive(:get).and_return(response)
      end

      it "fetches mod info from API" do
        result = api.get_mod("example-mod")
        expect(result).to eq(parsed_response)
      end

      it "stores response in cache" do
        api.get_mod("example-mod")
        expect(cache).to have_received(:store)
      end
    end

    context "when cache hit" do
      before do
        allow(cache).to receive(:read).with("cache_key", encoding: "UTF-8").and_return(response_body)
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
        allow(cache).to receive(:read).and_return(nil)
        allow(cache).to receive(:store)
        response = instance_double(Factorix::HTTP::Response, code: 200, body: response_body)
        allow(client).to receive(:get).and_return(response)
      end

      it "fetches full mod info from API" do
        result = api.get_mod_full("example-mod")
        expect(result).to eq(parsed_response)
      end

      it "stores response in cache" do
        api.get_mod_full("example-mod")
        expect(cache).to have_received(:store)
      end
    end

    context "when cache hit" do
      before do
        allow(cache).to receive(:read).with("cache_key", encoding: "UTF-8").and_return(response_body)
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
      allow(cache).to receive(:read).and_return(nil)
      allow(cache).to receive(:store)
    end

    context "when API returns 404" do
      before do
        allow(client).to receive(:get).and_raise(Factorix::HTTPClientError, "404 Not Found")
      end

      it "raises HTTPClientError" do
        expect { api.get_mod("nonexistent") }.to raise_error(Factorix::HTTPClientError, "404 Not Found")
      end
    end

    context "when API returns 500" do
      before do
        allow(client).to receive(:get).and_raise(Factorix::HTTPServerError, "500 Internal Server Error")
      end

      it "raises HTTPServerError" do
        expect { api.get_mods }.to raise_error(Factorix::HTTPServerError, "500 Internal Server Error")
      end
    end
  end

  describe "parameter validation" do
    describe "#get_mods" do
      let(:response_body) { '{"pagination": {}, "results": []}' }

      before do
        allow(cache).to receive(:read).and_return(nil)
        allow(cache).to receive(:store)
        response = instance_double(Factorix::HTTP::Response, code: 200, body: response_body)
        allow(client).to receive(:get).and_return(response)
      end

      context "with valid parameters" do
        it "accepts valid page_size as integer" do
          expect { api.get_mods(page_size: 10) }.not_to raise_error
        end

        it "accepts valid page_size as 'max'" do
          expect { api.get_mods(page_size: "max") }.not_to raise_error
        end

        it "accepts valid sort values" do
          %w[name created_at updated_at].each do |sort_value|
            expect { api.get_mods(sort: sort_value) }.not_to raise_error
          end
        end

        it "accepts valid sort_order values" do
          %w[asc desc].each do |order_value|
            expect { api.get_mods(sort_order: order_value) }.not_to raise_error
          end
        end

        it "accepts valid version values" do
          %w[0.13 0.14 0.15 0.16 0.17 0.18 1.0 1.1 2.0].each do |version_value|
            expect { api.get_mods(version: version_value) }.not_to raise_error
          end
        end
      end

      context "with invalid parameters" do
        it "raises ArgumentError for invalid page_size" do
          expect { api.get_mods(page_size: 0) }.to raise_error(ArgumentError, /page_size must be/)
          expect { api.get_mods(page_size: -1) }.to raise_error(ArgumentError, /page_size must be/)
          expect { api.get_mods(page_size: "invalid") }.to raise_error(ArgumentError, /page_size must be/)
        end

        it "raises ArgumentError for invalid sort" do
          expect { api.get_mods(sort: "invalid") }.to raise_error(ArgumentError, /sort must be one of/)
        end

        it "raises ArgumentError for invalid sort_order" do
          expect { api.get_mods(sort_order: "invalid") }.to raise_error(ArgumentError, /sort_order must be one of/)
        end

        it "raises ArgumentError for invalid version" do
          expect { api.get_mods(version: "9.9") }.to raise_error(ArgumentError, /version must be one of/)
        end
      end
    end
  end
end
