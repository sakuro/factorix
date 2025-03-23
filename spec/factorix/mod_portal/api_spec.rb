# frozen_string_literal: true

require_relative "../../../lib/factorix/mod_portal/api"

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

      it "contains mod entries" do
        aggregate_failures do
          expect(mod_list.results).to be_an(Array)
          expect(mod_list.results).to all(be_a(Factorix::ModPortal::Types::ModEntry))
          expect(mod_list.results).to all(have_attributes(latest_release: be_a(Factorix::ModPortal::Types::Release)))
        end
      end
    end

    context "when requesting mod by name" do
      let(:mod_list) { api.mods(namelist: "alien-biomes") }

      it "returns a ModList" do
        expect(mod_list).to be_a(Factorix::ModPortal::Types::ModList)
      end

      it "contains mod entry" do
        mod_entry = mod_list.results.first
        aggregate_failures do
          expect(mod_entry.name).to eq("alien-biomes")
          expect(mod_entry.releases).to all(be_a(Factorix::ModPortal::Types::Release))
          expect(mod_entry.latest_release).to be_nil
        end
      end
    end

    context "with invalid parameters" do
      it "raises ValidationError for invalid sort" do
        expect { api.mods(sort: "invalid") }.to raise_error(Factorix::ModPortal::ValidationError)
      end

      it "raises ValidationError for invalid sort_order" do
        expect { api.mods(sort_order: "invalid") }.to raise_error(Factorix::ModPortal::ValidationError)
      end

      it "raises ValidationError for invalid version" do
        expect { api.mods(version: "invalid") }.to raise_error(Factorix::ModPortal::ValidationError)
      end
    end
  end

  describe "#mod", :vcr do
    let(:mod) { api.mod("alien-biomes") }

    it "returns a Mod" do
      expect(mod).to be_a(Factorix::ModPortal::Types::Mod)
    end

    it "contains basic mod information" do
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

    context "with non-existent mod" do
      it "raises RequestError" do
        expect { api.mod("non_existent_mod") }.to raise_error(Factorix::ModPortal::RequestError)
      end
    end
  end

  describe "#mod_with_details", :vcr do
    let(:mod) { api.mod_with_details("alien-biomes") }

    it "returns a ModWithDetails" do
      expect(mod).to be_a(Factorix::ModPortal::Types::ModWithDetails)
    end

    it "contains basic mod information" do
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

    context "with non-existent mod" do
      it "raises RequestError" do
        expect { api.mod_with_details("non_existent_mod") }.to raise_error(Factorix::ModPortal::RequestError)
      end
    end
  end
end
