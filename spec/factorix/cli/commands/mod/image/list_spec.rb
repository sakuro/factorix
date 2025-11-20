# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Image::List do
  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Image::List.new(portal:) }

  before do
    # Suppress stdout
    allow($stdout).to receive(:puts)

    # Mock the Application container
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)
  end

  describe "#call" do
    context "when mod has images" do
      let(:mod_info) do
        Factorix::Types::MODInfo[
          name: "test-mod",
          title: "Test Mod",
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

      it "lists all images with their details" do
        command.call(mod_name: "test-mod")

        expect(portal).to have_received(:get_mod_full).with("test-mod")

        expected_json = JSON.pretty_generate([
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
                                             ])
        expect($stdout).to have_received(:puts).with(expected_json)
      end
    end

    context "when mod has no images" do
      let(:mod_info) do
        Factorix::Types::MODInfo[
          name: "test-mod",
          title: "Test Mod",
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

      it "displays empty array" do
        command.call(mod_name: "test-mod")

        expect(portal).to have_received(:get_mod_full).with("test-mod")
        expect($stdout).to have_received(:puts).with(JSON.pretty_generate([]))
      end
    end

    context "when mod has no detail" do
      let(:mod_info) do
        Factorix::Types::MODInfo[
          name: "test-mod",
          title: "Test Mod",
          owner: "test-user",
          summary: "Summary",
          downloads_count: 100,
          category: "content"
        ]
      end

      before do
        allow(portal).to receive(:get_mod_full).with("test-mod").and_return(mod_info)
      end

      it "displays empty array" do
        command.call(mod_name: "test-mod")

        expect(portal).to have_received(:get_mod_full).with("test-mod")
        expect($stdout).to have_received(:puts).with(JSON.pretty_generate([]))
      end
    end

    context "when errors occur" do
      before do
        allow(portal).to receive(:get_mod_full).and_raise(
          Factorix::HTTPClientError.new("404 Not Found")
        )
      end

      it "raises HTTPClientError" do
        expect {
          command.call(mod_name: "non-existent-mod")
        }.to raise_error(Factorix::HTTPClientError, /404 Not Found/)
      end
    end
  end
end
