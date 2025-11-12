# frozen_string_literal: true

RSpec.describe Factorix::Types::Release do
  describe "#initialize" do
    # NOTE: API layer converts JSON string keys to symbols via symbolize_names: true
    let(:release_hash) do
      {
        download_url: "/download/example-mod/1.0.0",
        file_name: "example-mod_1.0.0.zip",
        info_json: {
          "factorio_version" => "2.0",
          "dependencies" => ["base >= 2.0"]
        },
        released_at: "2024-10-21T12:34:56.000Z",
        version: "1.0.0",
        sha1: "abc123def456"
      }
    end

    it "creates Release from hash with keyword arguments" do
      release = Factorix::Types::Release[**release_hash]

      expect(release.download_url).to be_a(URI::HTTPS)
      expect(release.download_url.to_s).to eq("https://mods.factorio.com/download/example-mod/1.0.0")
      expect(release.file_name).to eq("example-mod_1.0.0.zip")
      expect(release.info_json).to eq({"factorio_version" => "2.0", "dependencies" => ["base >= 2.0"]})
      expect(release.version).to be_a(Factorix::Types::MODVersion)
      expect(release.version.to_s).to eq("1.0.0")
      expect(release.sha1).to eq("abc123def456")
    end

    it "converts released_at to UTC Time" do
      release = Factorix::Types::Release[**release_hash]

      expect(release.released_at).to be_a(Time)
      expect(release.released_at.utc?).to be(true)
      expect(release.released_at.iso8601).to eq("2024-10-21T12:34:56Z")
    end

    it "handles different time formats" do
      hash = release_hash.merge(released_at: "2024-10-21T12:34:56+09:00")
      release = Factorix::Types::Release[**hash]

      expect(release.released_at).to be_a(Time)
      expect(release.released_at.utc?).to be(true)
      expect(release.released_at.iso8601).to eq("2024-10-21T03:34:56Z")
    end

    context "feature_flags" do
      it "defaults to empty array when not provided" do
        release = Factorix::Types::Release[**release_hash]

        expect(release.feature_flags).to eq([])
      end

      it "accepts feature_flags parameter as array" do
        hash = release_hash.merge(feature_flags: ["quality", "space-travel"])
        release = Factorix::Types::Release[**hash]

        expect(release.feature_flags).to eq(["quality", "space-travel"])
      end
    end
  end
end
