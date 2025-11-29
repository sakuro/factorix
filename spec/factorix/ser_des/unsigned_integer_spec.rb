# frozen_string_literal: true

RSpec.describe Factorix::SerDes::UnsignedInteger do
  describe "#initialize" do
    it "accepts positive integers" do
      expect { Factorix::SerDes::UnsignedInteger.new(42) }.not_to raise_error
    end

    it "accepts zero" do
      expect { Factorix::SerDes::UnsignedInteger.new(0) }.not_to raise_error
    end

    it "raises ArgumentError for negative integers" do
      expect { Factorix::SerDes::UnsignedInteger.new(-5) }.to raise_error(ArgumentError, "value must be non-negative")
    end

    it "raises ArgumentError for non-Integer values" do
      expect { Factorix::SerDes::UnsignedInteger.new(3.14) }.to raise_error(ArgumentError, "value must be an Integer")
    end
  end

  describe "#value" do
    it "returns the wrapped value" do
      unsigned_int = Factorix::SerDes::UnsignedInteger.new(42)
      expect(unsigned_int.value).to eq(42)
    end
  end

  describe "arithmetic operations" do
    it "behaves like an Integer" do
      unsigned_int = Factorix::SerDes::UnsignedInteger.new(10)
      expect(unsigned_int + 5).to eq(15)
      expect(unsigned_int * 2).to eq(20)
      expect(unsigned_int - 3).to eq(7)
    end
  end

  describe "#==" do
    it "compares with another UnsignedInteger by value" do
      a = Factorix::SerDes::UnsignedInteger.new(42)
      b = Factorix::SerDes::UnsignedInteger.new(42)
      c = Factorix::SerDes::UnsignedInteger.new(10)

      expect(a).to eq(b)
      expect(a).not_to eq(c)
    end

    it "compares with a plain Integer by value" do
      unsigned_int = Factorix::SerDes::UnsignedInteger.new(42)
      expect(unsigned_int).to eq(42)
      expect(unsigned_int).not_to eq(10)
    end

    it "returns false for other types" do
      unsigned_int = Factorix::SerDes::UnsignedInteger.new(42)
      expect(unsigned_int).not_to eq("42")
      expect(unsigned_int).not_to eq(42.0)
    end
  end

  describe "#hash" do
    it "returns consistent hash values" do
      a = Factorix::SerDes::UnsignedInteger.new(42)
      b = Factorix::SerDes::UnsignedInteger.new(42)
      expect(a.hash).to eq(b.hash)
    end
  end

  describe "#inspect" do
    it "returns a meaningful string representation" do
      unsigned_int = Factorix::SerDes::UnsignedInteger.new(42)
      expect(unsigned_int.inspect).to match(/Factorix::SerDes::UnsignedInteger.*value=42/)
    end
  end
end
