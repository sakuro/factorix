# frozen_string_literal: true

RSpec.describe Factorix::Types::MODVersionRequirement do
  let(:version_1_0_0) { Factorix::Types::MODVersion.from_string("1.0.0") }
  let(:version_1_2_0) { Factorix::Types::MODVersion.from_string("1.2.0") }
  let(:version_1_3_0) { Factorix::Types::MODVersion.from_string("1.3.0") }
  let(:version_2_0_0) { Factorix::Types::MODVersion.from_string("2.0.0") }

  describe ".new" do
    context "with valid operator" do
      it "creates a requirement with '>=' operator" do
        requirement = Factorix::Types::MODVersionRequirement[operator: ">=", version: version_1_2_0]
        expect(requirement.operator).to eq(">=")
        expect(requirement.version).to eq(version_1_2_0)
      end

      it "creates a requirement with '=' operator" do
        requirement = Factorix::Types::MODVersionRequirement[operator: "=", version: version_1_2_0]
        expect(requirement.operator).to eq("=")
      end

      it "creates a requirement with '<' operator" do
        requirement = Factorix::Types::MODVersionRequirement[operator: "<", version: version_1_2_0]
        expect(requirement.operator).to eq("<")
      end
    end

    context "with invalid operator" do
      it "raises ArgumentError for invalid operator" do
        expect {
          Factorix::Types::MODVersionRequirement[operator: "!=", version: version_1_2_0]
        }.to raise_error(ArgumentError, /Invalid operator: !=/)
      end

      it "raises ArgumentError for empty operator" do
        expect {
          Factorix::Types::MODVersionRequirement[operator: "", version: version_1_2_0]
        }.to raise_error(ArgumentError, /Invalid operator/)
      end
    end

    context "with invalid version" do
      it "raises ArgumentError when version is not a MODVersion" do
        expect {
          Factorix::Types::MODVersionRequirement[operator: ">=", version: "1.2.0"]
        }.to raise_error(ArgumentError, /version must be a MODVersion/)
      end
    end
  end

  describe "#satisfied_by?" do
    context "with '=' operator" do
      let(:requirement) { Factorix::Types::MODVersionRequirement[operator: "=", version: version_1_2_0] }

      it "returns true for equal version" do
        expect(requirement.satisfied_by?(version_1_2_0)).to be(true)
      end

      it "returns false for higher version" do
        expect(requirement.satisfied_by?(version_1_3_0)).to be(false)
      end

      it "returns false for lower version" do
        expect(requirement.satisfied_by?(version_1_0_0)).to be(false)
      end
    end

    context "with '>=' operator" do
      let(:requirement) { Factorix::Types::MODVersionRequirement[operator: ">=", version: version_1_2_0] }

      it "returns true for equal version" do
        expect(requirement.satisfied_by?(version_1_2_0)).to be(true)
      end

      it "returns true for higher version" do
        expect(requirement.satisfied_by?(version_1_3_0)).to be(true)
        expect(requirement.satisfied_by?(version_2_0_0)).to be(true)
      end

      it "returns false for lower version" do
        expect(requirement.satisfied_by?(version_1_0_0)).to be(false)
      end
    end

    context "with '>' operator" do
      let(:requirement) { Factorix::Types::MODVersionRequirement[operator: ">", version: version_1_2_0] }

      it "returns false for equal version" do
        expect(requirement.satisfied_by?(version_1_2_0)).to be(false)
      end

      it "returns true for higher version" do
        expect(requirement.satisfied_by?(version_1_3_0)).to be(true)
        expect(requirement.satisfied_by?(version_2_0_0)).to be(true)
      end

      it "returns false for lower version" do
        expect(requirement.satisfied_by?(version_1_0_0)).to be(false)
      end
    end

    context "with '<=' operator" do
      let(:requirement) { Factorix::Types::MODVersionRequirement[operator: "<=", version: version_1_2_0] }

      it "returns true for equal version" do
        expect(requirement.satisfied_by?(version_1_2_0)).to be(true)
      end

      it "returns false for higher version" do
        expect(requirement.satisfied_by?(version_1_3_0)).to be(false)
        expect(requirement.satisfied_by?(version_2_0_0)).to be(false)
      end

      it "returns true for lower version" do
        expect(requirement.satisfied_by?(version_1_0_0)).to be(true)
      end
    end

    context "with '<' operator" do
      let(:requirement) { Factorix::Types::MODVersionRequirement[operator: "<", version: version_1_2_0] }

      it "returns false for equal version" do
        expect(requirement.satisfied_by?(version_1_2_0)).to be(false)
      end

      it "returns false for higher version" do
        expect(requirement.satisfied_by?(version_1_3_0)).to be(false)
        expect(requirement.satisfied_by?(version_2_0_0)).to be(false)
      end

      it "returns true for lower version" do
        expect(requirement.satisfied_by?(version_1_0_0)).to be(true)
      end
    end
  end

  describe "#to_s" do
    it "returns string representation with >= operator" do
      requirement = Factorix::Types::MODVersionRequirement[operator: ">=", version: version_1_2_0]
      expect(requirement.to_s).to eq(">= 1.2.0")
    end

    it "returns string representation with = operator" do
      requirement = Factorix::Types::MODVersionRequirement[operator: "=", version: version_1_2_0]
      expect(requirement.to_s).to eq("= 1.2.0")
    end

    it "returns string representation with < operator" do
      requirement = Factorix::Types::MODVersionRequirement[operator: "<", version: version_2_0_0]
      expect(requirement.to_s).to eq("< 2.0.0")
    end
  end
end
