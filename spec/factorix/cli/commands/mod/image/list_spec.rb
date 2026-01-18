# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Image::List do
  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Image::List.new(portal:) }

  before do
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)
  end

  describe "#call" do
    context "when MOD has images" do
      let(:mod_info) do
        Factorix::API::MODInfo[
          name: "test-mod",
          title: "Test MOD",
          owner: "test-user",
          summary: "Summary",
          downloads_count: 100,
          category: "content",
          changelog: "",
          created_at: "2024-01-01T00:00:00Z",
          updated_at: "2024-01-01T00:00:00Z",
          description: "Description",
          homepage: "",
          images: [
            {
              id: "abc123",
              thumbnail: "https://example.com/thumb1.jpg",
              url: "https://example.com/image1.jpg"
            },
            {
              id: "def456",
              thumbnail: "https://example.com/thumb2.jpg",
              url: "https://example.com/image2.jpg"
            }
          ],
          tags: []
        ]
      end

      before do
        allow(portal).to receive(:get_mod_full).with("test-mod").and_return(mod_info)
      end

      it "outputs table format by default" do
        result = run_command(command, %w[test-mod])

        expect(portal).to have_received(:get_mod_full).with("test-mod")
        expect(result.stdout).to include("ID")
        expect(result.stdout).to include("THUMBNAIL")
        expect(result.stdout).to include("URL")
        expect(result.stdout).to include("abc123")
        expect(result.stdout).to include("def456")
      end

      it "outputs JSON format with --json option" do
        result = run_command(command, %w[test-mod --json])

        expect(portal).to have_received(:get_mod_full).with("test-mod")

        json = JSON.parse(result.stdout)
        expect(json).to eq([
          {
            "id" => "abc123",
            "thumbnail" => "https://example.com/thumb1.jpg",
            "url" => "https://example.com/image1.jpg"
          },
          {
            "id" => "def456",
            "thumbnail" => "https://example.com/thumb2.jpg",
            "url" => "https://example.com/image2.jpg"
          }
        ])
      end
    end

    context "when MOD has no images" do
      let(:mod_info) do
        Factorix::API::MODInfo[
          name: "test-mod",
          title: "Test MOD",
          owner: "test-user",
          summary: "Summary",
          downloads_count: 100,
          category: "content",
          changelog: "",
          created_at: "2024-01-01T00:00:00Z",
          updated_at: "2024-01-01T00:00:00Z",
          description: "Description",
          homepage: "",
          images: [],
          tags: []
        ]
      end

      before do
        allow(portal).to receive(:get_mod_full).with("test-mod").and_return(mod_info)
      end

      it "displays 'No images found' in table format" do
        result = run_command(command, %w[test-mod])

        expect(portal).to have_received(:get_mod_full).with("test-mod")
        expect(result.stdout).to include("No images found")
      end

      it "displays empty array in JSON format" do
        result = run_command(command, %w[test-mod --json])

        expect(portal).to have_received(:get_mod_full).with("test-mod")
        expect(JSON.parse(result.stdout)).to eq([])
      end
    end

    context "when MOD has no detail" do
      let(:mod_info) do
        Factorix::API::MODInfo[
          name: "test-mod",
          title: "Test MOD",
          owner: "test-user",
          summary: "Summary",
          downloads_count: 100,
          category: "content"
        ]
      end

      before do
        allow(portal).to receive(:get_mod_full).with("test-mod").and_return(mod_info)
      end

      it "displays 'No images found' in table format" do
        result = run_command(command, %w[test-mod])

        expect(portal).to have_received(:get_mod_full).with("test-mod")
        expect(result.stdout).to include("No images found")
      end

      it "displays empty array in JSON format" do
        result = run_command(command, %w[test-mod --json])

        expect(portal).to have_received(:get_mod_full).with("test-mod")
        expect(JSON.parse(result.stdout)).to eq([])
      end
    end

    context "when MOD not found" do
      before do
        allow(portal).to receive(:get_mod_full).and_raise(
          Factorix::MODNotOnPortalError.new("MOD 'non-existent-mod' not found on portal")
        )
      end

      it "raises MODNotOnPortalError" do
        expect {
          run_command(command, %w[non-existent-mod])
        }.to raise_error(Factorix::MODNotOnPortalError, /not found on portal/)
      end
    end
  end
end
