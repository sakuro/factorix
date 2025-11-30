# frozen_string_literal: true

RSpec.describe Factorix::API::License do
  describe "#initialize" do
    it "creates a License with URI object for url" do
      license = Factorix::API::License[
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

  describe ".valid_identifier?" do
    it "returns true for standard license identifiers" do
      expect(Factorix::API::License.valid_identifier?("default_mit")).to be true
      expect(Factorix::API::License.valid_identifier?("default_gnugplv3")).to be true
      expect(Factorix::API::License.valid_identifier?("default_gnulgplv3")).to be true
      expect(Factorix::API::License.valid_identifier?("default_mozilla2")).to be true
      expect(Factorix::API::License.valid_identifier?("default_apache2")).to be true
      expect(Factorix::API::License.valid_identifier?("default_unlicense")).to be true
    end

    it "returns true for valid custom license identifiers" do
      expect(Factorix::API::License.valid_identifier?("custom_0123456789abcdef01234567")).to be true
      expect(Factorix::API::License.valid_identifier?("custom_abcdef0123456789abcdef01")).to be true
    end

    it "returns false for invalid custom license identifiers" do
      # Too short
      expect(Factorix::API::License.valid_identifier?("custom_0123456789abcdef0123456")).to be false
      # Too long
      expect(Factorix::API::License.valid_identifier?("custom_0123456789abcdef012345678")).to be false
      # Uppercase hex
      expect(Factorix::API::License.valid_identifier?("custom_0123456789ABCDEF01234567")).to be false
      # Missing prefix
      expect(Factorix::API::License.valid_identifier?("0123456789abcdef01234567")).to be false
    end

    it "returns false for unknown identifiers" do
      expect(Factorix::API::License.valid_identifier?("unknown")).to be false
      expect(Factorix::API::License.valid_identifier?("mit")).to be false
      expect(Factorix::API::License.valid_identifier?("")).to be false
    end
  end

  describe ".identifier_values" do
    it "returns all standard license identifier values" do
      values = Factorix::API::License.identifier_values

      expect(values).to include("default_mit")
      expect(values).to include("default_gnugplv3")
      expect(values).to include("default_gnulgplv3")
      expect(values).to include("default_mozilla2")
      expect(values).to include("default_apache2")
      expect(values).to include("default_unlicense")
      expect(values.size).to eq(6)
    end
  end
end
