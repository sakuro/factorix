# frozen_string_literal: true

RSpec.describe Factorix::Types::MODListEntry do
  describe "#initialize" do
    context "with latest_release (without namelist parameter)" do
      # NOTE: API layer converts JSON string keys to symbols via symbolize_names: true
      let(:entry_hash) do
        {
          name: "example-mod",
          title: "Example Mod",
          owner: "test-user",
          summary: "An example mod for testing",
          downloads_count: 1000,
          category: "utilities",
          score: 42.5,
          latest_release: {
            download_url: "/download/example-mod/1.0.0",
            file_name: "example-mod_1.0.0.zip",
            info_json: {"factorio_version" => "2.0"},
            released_at: "2024-10-21T12:34:56.000Z",
            version: "1.0.0",
            sha1: "abc123"
          }
        }
      end

      it "creates MODListEntry from hash with keyword arguments" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.name).to eq("example-mod")
        expect(entry.title).to eq("Example Mod")
        expect(entry.owner).to eq("test-user")
        expect(entry.summary).to eq("An example mod for testing")
        expect(entry.downloads_count).to eq(1000)
        expect(entry.score).to eq(42.5)
      end

      it "converts category string to Category object" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.category).to be_a(Factorix::Types::Category)
        expect(entry.category.value).to eq("utilities")
      end

      it "converts latest_release hash to Release object" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.latest_release).to be_a(Factorix::Types::Release)
        expect(entry.latest_release.version).to be_a(Factorix::Types::MODVersion)
        expect(entry.latest_release.version.to_s).to eq("1.0.0")
        expect(entry.latest_release.released_at).to be_a(Time)
      end

      it "sets releases to nil when not provided" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.releases).to be_nil
      end
    end

    context "with releases (with namelist parameter)" do
      let(:entry_hash) do
        {
          name: "example-mod",
          title: "Example Mod",
          owner: "test-user",
          summary: "An example mod for testing",
          downloads_count: 1000,
          category: "content",
          score: 10.0,
          releases: [
            {
              download_url: "/download/example-mod/0.9.0",
              file_name: "example-mod_0.9.0.zip",
              info_json: {"factorio_version" => "1.1"},
              released_at: "2024-08-15T10:00:00.000Z",
              version: "0.9.0",
              sha1: "def456"
            },
            {
              download_url: "/download/example-mod/1.0.0",
              file_name: "example-mod_1.0.0.zip",
              info_json: {"factorio_version" => "2.0"},
              released_at: "2024-10-21T12:34:56.000Z",
              version: "1.0.0",
              sha1: "abc123"
            }
          ]
        }
      end

      it "converts releases array to Release objects" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.releases).to be_an(Array)
        expect(entry.releases.size).to eq(2)
        expect(entry.releases.first).to be_a(Factorix::Types::Release)
        expect(entry.releases.last).to be_a(Factorix::Types::Release)
      end

      it "preserves releases order (oldest first, newest last)" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.releases.first.version.to_s).to eq("0.9.0")
        expect(entry.releases.first.released_at.iso8601).to eq("2024-08-15T10:00:00Z")
        expect(entry.releases.last.version.to_s).to eq("1.0.0")
        expect(entry.releases.last.released_at.iso8601).to eq("2024-10-21T12:34:56Z")
      end

      it "sets latest_release to nil when not provided" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.latest_release).to be_nil
      end
    end

    context "with empty releases array" do
      let(:entry_hash) do
        {
          name: "example-mod",
          title: "Example Mod",
          owner: "test-user",
          summary: "An example mod for testing",
          downloads_count: 1000,
          category: "tweaks",
          score: 5.0,
          releases: []
        }
      end

      it "sets releases to nil for empty array" do
        entry = Factorix::Types::MODListEntry.new(**entry_hash)

        expect(entry.releases).to be_nil
      end
    end
  end
end
