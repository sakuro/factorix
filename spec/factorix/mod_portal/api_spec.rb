# frozen_string_literal: true

RSpec.describe Factorix::ModPortal::API do
  subject(:api) { Factorix::ModPortal::API.new }

  describe "#mods", :vcr do
    context "when requesting first page" do
      let(:mod_list) { api.mods }

      it "returns a ModList" do
        expect(mod_list).to be_a(Factorix::ModPortal::Types::ModList)
      end

      it "contains pagination information" do
        aggregate_failures do
          expect(mod_list.pagination).to be_a(Factorix::ModPortal::Types::Pagination)
          expect(mod_list.pagination.page).to eq(1)
          expect(mod_list.pagination.page_count).to be > 0
        end
      end

      it "contains MOD entries" do
        aggregate_failures do
          expect(mod_list.results).to be_an(Array)
          expect(mod_list.results).to all(be_a(Factorix::ModPortal::Types::ModEntry))
          expect(mod_list.results).to all(have_attributes(latest_release: be_a(Factorix::ModPortal::Types::Release)))
        end
      end
    end

    context "when requesting MOD by name" do
      let(:mod_list) { api.mods(namelist: "alien-biomes") }

      it "returns a ModList" do
        expect(mod_list).to be_a(Factorix::ModPortal::Types::ModList)
      end

      it "contains MOD entry" do
        mod_entry = mod_list.results.first
        aggregate_failures do
          expect(mod_entry.name).to eq("alien-biomes")
          expect(mod_entry.releases).to all(be_a(Factorix::ModPortal::Types::Release))
          expect(mod_entry.latest_release).to be_nil
        end
      end
    end

    context "with connection errors" do
      before do
        stub_request(:get, "https://mods.factorio.com/api/mods").to_raise(error)
      end

      context "with connection timeout" do
        let(:error) { Net::OpenTimeout.new("execution expired") }

        it "raises RequestError" do
          expect { api.mods }.to raise_error(Factorix::ModPortalRequestError, "Connection timeout: execution expired")
        end
      end

      context "with read timeout" do
        let(:error) { Net::ReadTimeout.new("execution expired") }

        it "raises RequestError" do
          expect { api.mods }.to raise_error(Factorix::ModPortalRequestError, "Read timeout: Net::ReadTimeout with \"execution expired\"")
        end
      end

      context "with SSL error" do
        let(:error) { OpenSSL::SSL::SSLError.new("certificate verify failed") }

        it "raises RequestError" do
          expect { api.mods }.to raise_error(Factorix::ModPortalRequestError, "SSL/TLS error: certificate verify failed")
        end
      end

      context "with network error" do
        let(:error) { SocketError.new("getaddrinfo: Name or service not known") }

        it "raises RequestError" do
          expect { api.mods }.to raise_error(Factorix::ModPortalRequestError, "Network error: getaddrinfo: Name or service not known")
        end
      end

      context "with connection error" do
        let(:error) { Errno::ECONNREFUSED.new }

        it "raises RequestError" do
          expect { api.mods }.to raise_error(Factorix::ModPortalRequestError, "Connection error: Connection refused")
        end
      end

      context "with HTTP error" do
        let(:error_response) { StringIO.new('{"message":"Mod not found","status":404}') }
        let(:error) { OpenURI::HTTPError.new("404 Not Found", error_response) }

        it "raises RequestError" do
          expect { api.mods }.to raise_error(Factorix::ModPortalRequestError, "Client error: 404 Not Found")
        end
      end
    end

    context "with invalid parameters" do
      it "raises ValidationError for invalid sort" do
        expect { api.mods(sort: "invalid") }.to raise_error(Factorix::ModPortalValidationError)
      end

      it "raises ValidationError for invalid sort_order" do
        expect { api.mods(sort_order: "invalid") }.to raise_error(Factorix::ModPortalValidationError)
      end

      it "raises ValidationError for invalid version" do
        expect { api.mods(version: "invalid") }.to raise_error(Factorix::ModPortalValidationError)
      end
    end
  end

  describe "#mod", :vcr do
    let(:mod) { api.mod("alien-biomes") }

    it "returns a Mod" do
      expect(mod).to be_a(Factorix::ModPortal::Types::Mod)
    end

    it "contains basic MOD information" do
      aggregate_failures do
        expect(mod.name).to eq("alien-biomes")
        expect(mod.title).to eq("Alien Biomes")
        expect(mod.owner).to eq("Earendel")
        expect(mod.summary).to be_a(String)
        expect(mod.downloads_count).to be > 0
        expect(mod.category).to eq("Tweaks")
        expect(mod.releases).to all(be_a(Factorix::ModPortal::Types::Release))
      end
    end

    context "with non-existent MOD" do
      it "raises RequestError" do
        expect { api.mod("non_existent_mod") }.to raise_error(Factorix::ModPortalRequestError)
      end
    end
  end

  describe "#mod_with_details", :vcr do
    let(:mod) { api.mod_with_details("alien-biomes") }

    it "returns a ModWithDetails" do
      expect(mod).to be_a(Factorix::ModPortal::Types::ModWithDetails)
    end

    it "contains basic MOD information" do
      aggregate_failures do
        expect(mod.name).to eq("alien-biomes")
        expect(mod.title).to eq("Alien Biomes")
        expect(mod.owner).to eq("Earendel")
        expect(mod.summary).to be_a(String)
        expect(mod.downloads_count).to be > 0
        expect(mod.category).to eq("Tweaks")
      end
    end

    it "contains detailed information" do
      aggregate_failures do
        expect(mod.created_at).to be_a(Time)
        expect(mod.updated_at).to be_a(Time)
        expect(mod.description).to be_a(String)
        expect(mod.tags).to be_an(Array)
        expect(mod.releases).to all(be_a(Factorix::ModPortal::Types::Release))
      end
    end

    it "contains absolute URLs" do
      aggregate_failures do
        expect(mod.thumbnail).to be_a(URI)
        expect(mod.thumbnail.to_s).to start_with("https://assets-mod.factorio.com")
        expect(mod.releases.first.download_url).to be_a(URI)
        expect(mod.releases.first.download_url.to_s).to start_with("https://mods.factorio.com")
      end
    end

    context "with non-existent MOD" do
      it "raises RequestError" do
        expect { api.mod_with_details("non_existent_mod") }.to raise_error(Factorix::ModPortalRequestError)
      end
    end
  end
end
