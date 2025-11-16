# frozen_string_literal: true

RSpec.describe Factorix::Types::MODInfo do
  describe "#initialize" do
    context "with list API response (basic fields + latest_release)" do
      it "creates MODInfo with default values for missing fields" do
        mod_info = Factorix::Types::MODInfo[
          name: "test-mod",
          title: "Test Mod",
          owner: "testuser",
          downloads_count: 1000,
          latest_release: {
            download_url: "/download/test-mod/1.0.0",
            file_name: "test-mod_1.0.0.zip",
            info_json: {"name" => "test-mod"},
            released_at: "2025-01-01T00:00:00.000000Z",
            version: "1.0.0",
            sha1: "abc123"
          }
        ]

        expect(mod_info.name).to eq("test-mod")
        expect(mod_info.title).to eq("Test Mod")
        expect(mod_info.owner).to eq("testuser")
        expect(mod_info.summary).to eq("") # Default empty string
        expect(mod_info.downloads_count).to eq(1000)
        expect(mod_info.category.value).to eq("") # NO_CATEGORY
        expect(mod_info.category.name).to eq("No category") # NO_CATEGORY
        expect(mod_info.score).to eq(0.0) # Default 0.0
        expect(mod_info.thumbnail).to be_nil
        expect(mod_info.latest_release).to be_a(Factorix::Types::Release)
        expect(mod_info.releases).to eq([]) # Default empty array
        expect(mod_info.detail).to be_nil
      end
    end

    context "with list API response including optional fields" do
      it "creates MODInfo with provided values" do
        mod_info = Factorix::Types::MODInfo[
          name: "test-mod",
          title: "Test Mod",
          owner: "testuser",
          summary: "A test mod",
          downloads_count: 1000,
          category: "content",
          score: 0.85,
          thumbnail: "/assets/.thumb.png",
          releases: [
            {
              download_url: "/download/test-mod/1.0.0",
              file_name: "test-mod_1.0.0.zip",
              info_json: {"name" => "test-mod"},
              released_at: "2025-01-01T00:00:00.000000Z",
              version: "1.0.0",
              sha1: "abc123"
            }
          ]
        ]

        expect(mod_info.summary).to eq("A test mod")
        expect(mod_info.category.value).to eq("content")
        expect(mod_info.category.name).to eq("Content")
        expect(mod_info.score).to eq(0.85)
        expect(mod_info.thumbnail).to be_a(URI::HTTPS)
        expect(mod_info.thumbnail.to_s).to eq("https://assets-mod.factorio.com/assets/.thumb.png")
        expect(mod_info.releases.size).to eq(1)
        expect(mod_info.releases.first).to be_a(Factorix::Types::Release)
      end
    end

    context "with Short API response" do
      it "creates MODInfo without detail" do
        mod_info = Factorix::Types::MODInfo[
          name: "short-mod",
          title: "Short Mod",
          owner: "owner",
          summary: "Summary",
          downloads_count: 500,
          category: "utilities",
          score: 0.9,
          thumbnail: "/assets/short.png",
          releases: []
        ]

        expect(mod_info.name).to eq("short-mod")
        expect(mod_info.detail).to be_nil
        expect(mod_info.releases).to eq([])
      end

      it "does not create detail when only some detail fields are present" do
        mod_info = Factorix::Types::MODInfo[
          name: "partial-mod",
          title: "Partial Mod",
          owner: "owner",
          downloads_count: 100,
          created_at: "2024-01-01T00:00:00.000000Z"
          # Missing updated_at and homepage
        ]

        expect(mod_info.detail).to be_nil
      end
    end

    context "with Full API response" do
      it "creates MODInfo with Detail" do
        mod_info = Factorix::Types::MODInfo[
          name: "full-mod",
          title: "Full Mod",
          owner: "owner",
          summary: "Summary",
          downloads_count: 2000,
          category: "overhaul",
          score: 0.95,
          thumbnail: "/assets/full.png",
          releases: [],
          changelog: "Version 1.0.0:\n  - Initial release",
          created_at: "2024-01-01T00:00:00.000000Z",
          updated_at: "2025-01-01T00:00:00.000000Z",
          last_highlighted_at: "2025-01-05T00:00:00.000000Z",
          description: "A detailed description",
          source_url: "https://github.com/user/full-mod",
          homepage: "https://example.com",
          faq: "Q: How to install?\nA: Just download it.",
          tags: %w[combat logistics],
          license: {
            id: "mit",
            name: "MIT",
            title: "MIT License",
            description: "Permissive",
            url: "https://opensource.org/licenses/MIT"
          },
          images: [
            {
              id: "img1",
              thumbnail: "https://assets-mod.factorio.com/assets/img1_thumb.png",
              url: "https://assets-mod.factorio.com/assets/img1.png"
            }
          ],
          deprecated: true
        ]

        expect(mod_info.detail).to be_a(Factorix::Types::MODInfo::Detail)
        expect(mod_info.detail.changelog).to eq("Version 1.0.0:\n  - Initial release")
        expect(mod_info.detail.created_at).to be_a(Time)
        expect(mod_info.detail.updated_at).to be_a(Time)
        expect(mod_info.detail.last_highlighted_at).to be_a(Time)
        expect(mod_info.detail.description).to eq("A detailed description")
        expect(mod_info.detail.source_url).to be_a(URI::HTTPS)
        expect(mod_info.detail.homepage).to be_a(URI)
        expect(mod_info.detail.homepage.to_s).to eq("https://example.com")
        expect(mod_info.detail.faq).to eq("Q: How to install?\nA: Just download it.")
        expect(mod_info.detail.tags.size).to eq(2)
        expect(mod_info.detail.tags.first).to be_a(Factorix::Types::Tag)
        expect(mod_info.detail.tags.map(&:value)).to eq(%w[combat logistics])
        expect(mod_info.detail.license).to be_a(Factorix::Types::License)
        expect(mod_info.detail.images.size).to eq(1)
        expect(mod_info.detail.images.first).to be_a(Factorix::Types::Image)
        expect(mod_info.detail.deprecated).to be(true)
        expect(mod_info.detail.deprecated?).to be(true)
      end
    end

    context "with Full API response and missing optional Detail fields" do
      it "uses default values for missing fields" do
        mod_info = Factorix::Types::MODInfo[
          name: "minimal-full",
          title: "Minimal Full",
          owner: "owner",
          downloads_count: 100,
          created_at: "2024-01-01T00:00:00.000000Z",
          updated_at: "2025-01-01T00:00:00.000000Z",
          homepage: "https://example.com"
        ]

        expect(mod_info.detail).to be_a(Factorix::Types::MODInfo::Detail)
        expect(mod_info.detail.changelog).to eq("") # Default
        expect(mod_info.detail.last_highlighted_at).to be_nil # Optional
        expect(mod_info.detail.description).to eq("") # Default
        expect(mod_info.detail.source_url).to be_nil # Optional
        expect(mod_info.detail.faq).to eq("") # Default
        expect(mod_info.detail.tags).to eq([]) # Default
        expect(mod_info.detail.license).to be_nil # Optional
        expect(mod_info.detail.images).to eq([]) # Default
        expect(mod_info.detail.deprecated).to be(false) # Default
        expect(mod_info.detail.deprecated?).to be(false)
      end
    end

    context "with invalid homepage URL" do
      it "raises URI::InvalidURIError" do
        expect {
          Factorix::Types::MODInfo[
            name: "test-mod",
            title: "Test",
            owner: "owner",
            downloads_count: 100,
            created_at: "2024-01-01T00:00:00.000000Z",
            updated_at: "2025-01-01T00:00:00.000000Z",
            homepage: "not a valid url but some text"
          ]
        }.to raise_error(URI::InvalidURIError)
      end
    end
  end

  describe "Detail#deprecated?" do
    it "returns true when deprecated is true" do
      detail = described_class::Detail[
        created_at: "2024-01-01T00:00:00.000000Z",
        updated_at: "2025-01-01T00:00:00.000000Z",
        homepage: "https://example.com",
        deprecated: true
      ]

      expect(detail.deprecated?).to be(true)
    end

    it "returns false when deprecated is false" do
      detail = described_class::Detail[
        created_at: "2024-01-01T00:00:00.000000Z",
        updated_at: "2025-01-01T00:00:00.000000Z",
        homepage: "https://example.com",
        deprecated: false
      ]

      expect(detail.deprecated?).to be(false)
    end

    it "returns false when deprecated is nil (default)" do
      detail = described_class::Detail[
        created_at: "2024-01-01T00:00:00.000000Z",
        updated_at: "2025-01-01T00:00:00.000000Z",
        homepage: "https://example.com"
      ]

      expect(detail.deprecated?).to be(false)
    end
  end
end
