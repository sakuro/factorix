# frozen_string_literal: true

RSpec.describe Factorix::Types::MODVersion do
  describe ".from_string" do
    it "creates a version from a string" do
      version = Factorix::Types::MODVersion.from_string("1.2.3")
      expect(version).to be_an_instance_of(Factorix::Types::MODVersion)
      expect(version.major).to eq(1)
      expect(version.minor).to eq(2)
      expect(version.patch).to eq(3)
    end

    it "raises ArgumentError for invalid version strings" do
      aggregate_failures "invalid version strings" do
        expect { Factorix::Types::MODVersion.from_string("1.2") }.to raise_error(ArgumentError)
        expect { Factorix::Types::MODVersion.from_string("1.2.3.4") }.to raise_error(ArgumentError)
        expect { Factorix::Types::MODVersion.from_string("a.b.c") }.to raise_error(ArgumentError)
      end
    end

    it "raises ArgumentError for component out of range" do
      expect { Factorix::Types::MODVersion.from_string("256.0.0") }.to raise_error(ArgumentError, /major/)
      expect { Factorix::Types::MODVersion.from_string("0.256.0") }.to raise_error(ArgumentError, /minor/)
      expect { Factorix::Types::MODVersion.from_string("0.0.256") }.to raise_error(ArgumentError, /patch/)
    end
  end

  describe ".from_numbers" do
    it "creates a version from integers" do
      version = Factorix::Types::MODVersion.from_numbers(1, 2, 3)
      expect(version).to be_an_instance_of(Factorix::Types::MODVersion)
      expect(version.major).to eq(1)
      expect(version.minor).to eq(2)
      expect(version.patch).to eq(3)
    end

    it "raises ArgumentError for invalid integers" do
      aggregate_failures "invalid integers" do
        expect { Factorix::Types::MODVersion.from_numbers(256, 0, 0) }.to raise_error(ArgumentError, /major/)
        expect { Factorix::Types::MODVersion.from_numbers(0, 256, 0) }.to raise_error(ArgumentError, /minor/)
        expect { Factorix::Types::MODVersion.from_numbers(0, 0, 256) }.to raise_error(ArgumentError, /patch/)
        expect { Factorix::Types::MODVersion.from_numbers(-1, 0, 0) }.to raise_error(ArgumentError, /major/)
      end
    end
  end

  describe "private constructors" do
    it "does not allow direct instantiation via new" do
      expect {
        Factorix::Types::MODVersion.new(major: 1, minor: 2, patch: 3)
      }.to raise_error(NoMethodError, /private method/)
    end

    it "does not allow direct instantiation via []" do
      expect {
        Factorix::Types::MODVersion[major: 1, minor: 2, patch: 3]
      }.to raise_error(NoMethodError, /private method/)
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expect(Factorix::Types::MODVersion.from_numbers(1, 2, 3).to_s).to eq("1.2.3")
    end
  end

  describe "#to_a" do
    it "returns an array of integers" do
      expect(Factorix::Types::MODVersion.from_numbers(1, 2, 3).to_a).to eq([1, 2, 3])
    end

    it "returns a frozen array" do
      expect(Factorix::Types::MODVersion.from_numbers(1, 2, 3).to_a).to be_frozen
    end
  end

  describe "#<=>" do
    let(:version_123) { Factorix::Types::MODVersion.from_numbers(1, 2, 3) }
    let(:version_124) { Factorix::Types::MODVersion.from_numbers(1, 2, 4) }
    let(:version_130) { Factorix::Types::MODVersion.from_numbers(1, 3, 0) }
    let(:version_200) { Factorix::Types::MODVersion.from_numbers(2, 0, 0) }
    let(:version_123_dup) { Factorix::Types::MODVersion.from_numbers(1, 2, 3) }

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
