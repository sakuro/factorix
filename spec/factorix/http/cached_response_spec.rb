# frozen_string_literal: true

RSpec.describe Factorix::HTTP::CachedResponse do
  let(:cached_response) { Factorix::HTTP::CachedResponse.new("test body") }

  describe "#initialize" do
    it "sets body from parameter" do
      expect(cached_response.body).to eq("test body")
    end

    it "sets code to 200" do
      expect(cached_response.code).to eq(200)
    end

    it "sets default headers" do
      expect(cached_response.headers).to eq({"content-type" => ["application/octet-stream"]})
    end
  end

  describe "#success?" do
    it "always returns true" do
      expect(cached_response.success?).to be true
    end
  end

  describe "#content_length" do
    it "returns byte size of body" do
      expect(cached_response.content_length).to eq(9) # "test body".bytesize
    end

    it "handles UTF-8 multibyte characters" do
      utf8_response = Factorix::HTTP::CachedResponse.new("こんにちは")
      expect(utf8_response.content_length).to eq(15) # 5 characters × 3 bytes each
    end
  end
end
