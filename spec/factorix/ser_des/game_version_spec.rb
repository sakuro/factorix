# frozen_string_literal: true

RSpec.describe Factorix::SerDes::GameVersion do
  describe ".new" do
    context "with version string" do
      it "creates a version from a string" do
        expect(Factorix::SerDes::GameVersion.new("1.2.3-4")).to be_an_instance_of(Factorix::SerDes::GameVersion)
      end

      it "creates a version from a string without build number" do
        expect(Factorix::SerDes::GameVersion.new("1.2.3")).to be_an_instance_of(Factorix::SerDes::GameVersion)
      end

      it "raises ArgumentError for invalid version string" do
        aggregate_failures "invalid version strings" do
          expect { Factorix::SerDes::GameVersion.new("1.2") }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::GameVersion.new("1.2.3.4") }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::GameVersion.new("a.b.c-d") }.to raise_error(ArgumentError)
        end
      end
    end

    context "with integers" do
      it "creates a version from integers" do
        expect(Factorix::SerDes::GameVersion.new(1, 2, 3, 4)).to be_an_instance_of(Factorix::SerDes::GameVersion)
      end

      it "raises ArgumentError for invalid integers" do
        aggregate_failures "invalid integers" do
          expect { Factorix::SerDes::GameVersion.new(1, 2, 3) }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::GameVersion.new(1, 2, 3, 4, 5) }.to raise_error(ArgumentError)
          expect { Factorix::SerDes::GameVersion.new(65536, 0, 0, 0) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe ".[]" do
    it "is an alias for new" do
      expect(Factorix::SerDes::GameVersion[1, 2, 3, 4]).to be_an_instance_of(Factorix::SerDes::GameVersion)
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expect(Factorix::SerDes::GameVersion.new(1, 2, 3, 4).to_s).to eq("1.2.3-4")
    end

    it "includes build number 0 in string representation" do
      expect(Factorix::SerDes::GameVersion.new("1.2.3").to_s).to eq("1.2.3-0")
    end
  end

  describe "#to_a" do
    it "returns an array of integers" do
      expect(Factorix::SerDes::GameVersion.new(1, 2, 3, 4).to_a).to eq([1, 2, 3, 4])
    end

    it "returns a frozen array" do
      expect(Factorix::SerDes::GameVersion.new(1, 2, 3, 4).to_a).to be_frozen
    end
  end

  describe "#<=>" do
    let(:version_1234) { Factorix::SerDes::GameVersion.new(1, 2, 3, 4) }
    let(:version_1235) { Factorix::SerDes::GameVersion.new(1, 2, 3, 5) }
    let(:version_1240) { Factorix::SerDes::GameVersion.new(1, 2, 4, 0) }
    let(:version_1300) { Factorix::SerDes::GameVersion.new(1, 3, 0, 0) }
    let(:version_2000) { Factorix::SerDes::GameVersion.new(2, 0, 0, 0) }
    let(:version_1234_dup) { Factorix::SerDes::GameVersion.new(1, 2, 3, 4) }

    it "considers equal versions as equal" do
      expect(version_1234 <=> version_1234_dup).to eq(0)
    end

    it "considers lower build version less than higher build version" do
      expect(version_1234 <=> version_1235).to eq(-1)
    end

    it "considers higher build version greater than lower build version" do
      expect(version_1235 <=> version_1234).to eq(1)
    end

    it "considers lower patch version less than higher patch version" do
      expect(version_1234 <=> version_1240).to eq(-1)
    end

    it "considers higher patch version greater than lower patch version" do
      expect(version_1240 <=> version_1234).to eq(1)
    end

    it "considers lower minor version less than higher minor version" do
      expect(version_1234 <=> version_1300).to eq(-1)
    end

    it "considers higher minor version greater than lower minor version" do
      expect(version_1300 <=> version_1234).to eq(1)
    end

    it "considers lower major version less than higher major version" do
      expect(version_1234 <=> version_2000).to eq(-1)
    end

    it "considers higher major version greater than lower major version" do
      expect(version_2000 <=> version_1234).to eq(1)
    end
  end
end
