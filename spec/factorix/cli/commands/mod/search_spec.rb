# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Search do
  include_context "with suppressed output"

  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Search.new(portal:) }

  let(:mod_info) do
    Factorix::Types::MODInfo.new(
      name: "test-mod",
      title: "Test MOD",
      owner: "test-owner",
      summary: "A test MOD",
      downloads_count: 100,
      category: "utilities",
      score: 5.0,
      thumbnail: nil,
      latest_release: nil,
      releases: []
    )
  end

  before do
    allow(Factorix::Application).to receive(:[]).and_call_original
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)
  end

  describe "#call" do
    before do
      allow(portal).to receive(:list_mods).and_return([mod_info])
    end

    it "passes options to portal.list_mods" do
      command.call(
        hide_deprecated: true,
        page: 2,
        page_size: 50,
        sort: "name",
        sort_order: "asc",
        version: "2.0"
      )

      expect(portal).to have_received(:list_mods).with(
        hide_deprecated: true,
        page: 2,
        page_size: 50,
        sort: "name",
        sort_order: "asc",
        version: "2.0"
      )
    end
  end
end
