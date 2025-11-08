# frozen_string_literal: true

RSpec.describe Factorix::SerDes::MODVersion do
  describe ".new" do
    context "with version string" do
      it "creates a version from a string" do
        expect(Factorix::SerDes::MODVersion.new("1.2.3")).to be_an_instance_of(Factorix::SerDes::MODVersion)
      end

      it "raises ArgumentError for invalid version string" do
        aggregate_failures "invalid version strings" do
          expect { Factorix::SerDes::MODVersion.new("1.2") }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::MODVersion.new("1.2.3.4") }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::MODVersion.new("a.b.c") }.to raise_error(ArgumentError)
        end
      end
    end

    context "with integers" do
      it "creates a version from integers" do
        expect(Factorix::SerDes::MODVersion.new(1, 2, 3)).to be_an_instance_of(Factorix::SerDes::MODVersion)
      end

      it "raises ArgumentError for invalid integers" do
        aggregate_failures "invalid integers" do
          expect { Factorix::SerDes::MODVersion.new(1, 2) }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::MODVersion.new(1, 2, 3, 4) }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::MODVersion.new(256, 0, 0) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe ".[]" do
    it "is an alias for new" do
      expect(Factorix::SerDes::MODVersion[1, 2, 3]).to be_an_instance_of(Factorix::SerDes::MODVersion)
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expect(Factorix::SerDes::MODVersion.new(1, 2, 3).to_s).to eq("1.2.3")
    end
  end

  describe "#to_a" do
    it "returns an array of integers" do
      expect(Factorix::SerDes::MODVersion.new(1, 2, 3).to_a).to eq([1, 2, 3])
    end

    it "returns a frozen array" do
      expect(Factorix::SerDes::MODVersion.new(1, 2, 3).to_a).to be_frozen
    end
  end

  describe "#<=>" do
    let(:version_123) { Factorix::SerDes::MODVersion.new(1, 2, 3) }
    let(:version_124) { Factorix::SerDes::MODVersion.new(1, 2, 4) }
    let(:version_130) { Factorix::SerDes::MODVersion.new(1, 3, 0) }
    let(:version_200) { Factorix::SerDes::MODVersion.new(2, 0, 0) }
    let(:version_123_dup) { Factorix::SerDes::MODVersion.new(1, 2, 3) }

    it "considers equal versions as equal" do
      expect(version_123 <=> version_123_dup).to eq(0)
    end

    it "considers lower patch version less than higher patch version" do
      expect(version_123 <=> version_124).to eq(-1)
    end

    it "considers higher patch version greater than lower patch version" do
      expect(version_124 <=> version_123).to eq(1)
    end

    it "considers lower minor version less than higher minor version" do
      expect(version_123 <=> version_130).to eq(-1)
    end

    it "considers higher minor version greater than lower minor version" do
      expect(version_130 <=> version_123).to eq(1)
    end

    it "considers lower major version less than higher major version" do
      expect(version_123 <=> version_200).to eq(-1)
    end

    it "considers higher major version greater than lower major version" do
      expect(version_200 <=> version_123).to eq(1)
    end
  end
end
