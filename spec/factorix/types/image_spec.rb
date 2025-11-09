# frozen_string_literal: true

RSpec.describe Factorix::Types::Image do
  describe "#initialize" do
    it "creates an Image with URI objects for thumbnail and url" do
      image = Factorix::Types::Image.new(
        id: "12345",
        thumbnail: "https://assets-mod.factorio.com/assets/12345/thumb.png",
        url: "https://assets-mod.factorio.com/assets/12345/full.png"
      )

      expect(image.id).to eq("12345")
      expect(image.thumbnail).to be_a(URI::HTTPS)
      expect(image.thumbnail.to_s).to eq("https://assets-mod.factorio.com/assets/12345/thumb.png")
      expect(image.url).to be_a(URI::HTTPS)
      expect(image.url.to_s).to eq("https://assets-mod.factorio.com/assets/12345/full.png")
    end

    it "handles different URL formats" do
      image = Factorix::Types::Image.new(
        id: "abc",
        thumbnail: "https://example.com/thumb.jpg",
        url: "https://example.com/full.jpg"
      )

      expect(image.thumbnail).to be_a(URI::HTTPS)
      expect(image.url).to be_a(URI::HTTPS)
    end
  end
end
