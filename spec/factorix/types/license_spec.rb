# frozen_string_literal: true

RSpec.describe Factorix::Types::License do
  describe "#initialize" do
    it "creates a License with URI object for url" do
      license = Factorix::Types::License[
        id: "mit",
        name: "MIT",
        title: "MIT License",
        description: "A permissive license",
        url: "https://opensource.org/licenses/MIT"
      ]

      expect(license.id).to eq("mit")
      expect(license.name).to eq("MIT")
      expect(license.title).to eq("MIT License")
      expect(license.description).to eq("A permissive license")
      expect(license.url).to be_a(URI::HTTPS)
      expect(license.url.to_s).to eq("https://opensource.org/licenses/MIT")
    end
  end
end
