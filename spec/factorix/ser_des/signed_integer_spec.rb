# frozen_string_literal: true

RSpec.describe Factorix::SerDes::SignedInteger do
  describe "#initialize" do
    it "accepts positive integers" do
      expect { Factorix::SerDes::SignedInteger.new(42) }.not_to raise_error
    end

    it "accepts negative integers" do
      expect { Factorix::SerDes::SignedInteger.new(-5) }.not_to raise_error
    end

    it "accepts zero" do
      expect { Factorix::SerDes::SignedInteger.new(0) }.not_to raise_error
    end

    it "raises ArgumentError for non-Integer values" do
      expect { Factorix::SerDes::SignedInteger.new(3.14) }.to raise_error(ArgumentError, "value must be an Integer")
    end
  end

  describe "#value" do
    it "returns the wrapped value" do
      signed_int = Factorix::SerDes::SignedInteger.new(42)
      expect(signed_int.value).to eq(42)
    end
  end

  describe "arithmetic operations" do
    it "behaves like an Integer" do
      signed_int = Factorix::SerDes::SignedInteger.new(10)
      expect(signed_int + 5).to eq(15)
      expect(signed_int * 2).to eq(20)
      expect(signed_int - 3).to eq(7)
    end
  end

  describe "#==" do
    it "compares with another SignedInteger by value" do
      a = Factorix::SerDes::SignedInteger.new(42)
      b = Factorix::SerDes::SignedInteger.new(42)
      c = Factorix::SerDes::SignedInteger.new(10)

      expect(a).to eq(b)
      expect(a).not_to eq(c)
    end

    it "compares with a plain Integer by value" do
      signed_int = Factorix::SerDes::SignedInteger.new(42)
      expect(signed_int).to eq(42)
      expect(signed_int).not_to eq(10)
    end

    it "returns false for other types" do
      signed_int = Factorix::SerDes::SignedInteger.new(42)
      expect(signed_int).not_to eq("42")
      expect(signed_int).not_to eq(42.0)
    end
  end

  describe "#hash" do
    it "returns consistent hash values" do
      a = Factorix::SerDes::SignedInteger.new(42)
      b = Factorix::SerDes::SignedInteger.new(42)
      expect(a.hash).to eq(b.hash)
    end
  end

  describe "#inspect" do
    it "returns a meaningful string representation" do
      signed_int = Factorix::SerDes::SignedInteger.new(42)
      expect(signed_int.inspect).to match(/Factorix::SerDes::SignedInteger.*value=42/)
    end
  end
end
