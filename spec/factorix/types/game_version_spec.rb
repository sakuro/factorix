# frozen_string_literal: true

RSpec.describe Factorix::Types::GameVersion do
  describe ".from_string" do
    it "creates a version from a string with build number" do
      version = Factorix::Types::GameVersion.from_string("1.2.3-4")
      expect(version).to be_an_instance_of(Factorix::Types::GameVersion)
      expect(version.major).to eq(1)
      expect(version.minor).to eq(2)
      expect(version.patch).to eq(3)
      expect(version.build).to eq(4)
    end

    it "creates a version from a string without build number (defaults to 0)" do
      version = Factorix::Types::GameVersion.from_string("1.2.3")
      expect(version).to be_an_instance_of(Factorix::Types::GameVersion)
      expect(version.build).to eq(0)
    end

    it "raises ArgumentError for invalid version strings" do
      aggregate_failures "invalid version strings" do
        expect { Factorix::Types::GameVersion.from_string("1.2") }.to raise_error(ArgumentError)
        expect { Factorix::Types::GameVersion.from_string("1.2.3.4") }.to raise_error(ArgumentError)
        expect { Factorix::Types::GameVersion.from_string("a.b.c-d") }.to raise_error(ArgumentError)
      end
    end

    it "raises ArgumentError for component out of range" do
      expect { Factorix::Types::GameVersion.from_string("65536.0.0-0") }.to raise_error(ArgumentError, /major/)
      expect { Factorix::Types::GameVersion.from_string("0.65536.0-0") }.to raise_error(ArgumentError, /minor/)
      expect { Factorix::Types::GameVersion.from_string("0.0.65536-0") }.to raise_error(ArgumentError, /patch/)
      expect { Factorix::Types::GameVersion.from_string("0.0.0-65536") }.to raise_error(ArgumentError, /build/)
    end
  end

  describe ".from_numbers" do
    it "creates a version from integers" do
      version = Factorix::Types::GameVersion.from_numbers(1, 2, 3, 4)
      expect(version).to be_an_instance_of(Factorix::Types::GameVersion)
      expect(version.major).to eq(1)
      expect(version.minor).to eq(2)
      expect(version.patch).to eq(3)
      expect(version.build).to eq(4)
    end

    it "raises ArgumentError for invalid integers" do
      aggregate_failures "invalid integers" do
        expect { Factorix::Types::GameVersion.from_numbers(65536, 0, 0, 0) }.to raise_error(ArgumentError, /major/)
        expect { Factorix::Types::GameVersion.from_numbers(0, 65536, 0, 0) }.to raise_error(ArgumentError, /minor/)
        expect { Factorix::Types::GameVersion.from_numbers(0, 0, 65536, 0) }.to raise_error(ArgumentError, /patch/)
        expect { Factorix::Types::GameVersion.from_numbers(0, 0, 0, 65536) }.to raise_error(ArgumentError, /build/)
        expect { Factorix::Types::GameVersion.from_numbers(-1, 0, 0, 0) }.to raise_error(ArgumentError, /major/)
      end
    end
  end

  describe "private constructors" do
    it "does not allow direct instantiation via new" do
      expect {
        Factorix::Types::GameVersion.new(major: 1, minor: 2, patch: 3, build: 4)
      }.to raise_error(NoMethodError, /private method/)
    end

    it "does not allow direct instantiation via []" do
      expect {
        Factorix::Types::GameVersion[major: 1, minor: 2, patch: 3, build: 4]
      }.to raise_error(NoMethodError, /private method/)
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expect(Factorix::Types::GameVersion.from_numbers(1, 2, 3, 4).to_s).to eq("1.2.3-4")
    end

    it "omits build number when it is 0" do
      expect(Factorix::Types::GameVersion.from_string("1.2.3").to_s).to eq("1.2.3")
    end
  end

  describe "#to_a" do
    it "returns an array of integers" do
      expect(Factorix::Types::GameVersion.from_numbers(1, 2, 3, 4).to_a).to eq([1, 2, 3, 4])
    end

    it "returns a frozen array" do
      expect(Factorix::Types::GameVersion.from_numbers(1, 2, 3, 4).to_a).to be_frozen
    end
  end

  describe "#<=>" do
    let(:version_1234) { Factorix::Types::GameVersion.from_numbers(1, 2, 3, 4) }
    let(:version_1235) { Factorix::Types::GameVersion.from_numbers(1, 2, 3, 5) }
    let(:version_1240) { Factorix::Types::GameVersion.from_numbers(1, 2, 4, 0) }
    let(:version_1300) { Factorix::Types::GameVersion.from_numbers(1, 3, 0, 0) }
    let(:version_2000) { Factorix::Types::GameVersion.from_numbers(2, 0, 0, 0) }
    let(:version_1234_dup) { Factorix::Types::GameVersion.from_numbers(1, 2, 3, 4) }

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
