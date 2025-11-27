# frozen_string_literal: true

RSpec.describe Factorix::Formatting do
  let(:formatter) { Class.new { include Factorix::Formatting }.new }

  describe "#format_size" do
    it "returns 'unlimited' for nil" do
      expect(formatter.format_size(nil)).to eq("unlimited")
    end

    it "returns '0 B' for zero" do
      expect(formatter.format_size(0)).to eq("0 B")
    end

    it "formats bytes" do
      expect(formatter.format_size(512)).to eq("512 B")
    end

    it "formats kibibytes" do
      expect(formatter.format_size(1536)).to eq("1.5 KiB")
    end

    it "formats mebibytes" do
      expect(formatter.format_size(10 * 1024 * 1024)).to eq("10.0 MiB")
    end

    it "formats gibibytes" do
      expect(formatter.format_size(2 * 1024 * 1024 * 1024)).to eq("2.0 GiB")
    end

    it "formats tebibytes" do
      expect(formatter.format_size(3 * 1024 * 1024 * 1024 * 1024)).to eq("3.0 TiB")
    end
  end

  describe "#format_duration" do
    it "returns '-' for nil" do
      expect(formatter.format_duration(nil)).to eq("-")
    end

    it "formats seconds" do
      expect(formatter.format_duration(45)).to eq("45s")
    end

    it "formats minutes" do
      expect(formatter.format_duration(120)).to eq("2m")
    end

    it "formats hours and minutes" do
      expect(formatter.format_duration(3661)).to eq("1h 1m")
    end

    it "formats days and hours" do
      expect(formatter.format_duration(90000)).to eq("1d 1h")
    end

    it "handles float input" do
      expect(formatter.format_duration(90.5)).to eq("1m")
    end
  end
end
