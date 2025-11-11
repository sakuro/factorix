# frozen_string_literal: true

RSpec.describe Factorix::MODDependencyParser do
  subject(:parser) { Factorix::MODDependencyParser.new }

  describe "#parse" do
    context "with required dependencies" do
      it "parses simple required dependency" do
        dep = parser.parse("base")
        expect(dep.mod_name).to eq("base")
        expect(dep.type).to eq(:required)
        expect(dep.version_requirement).to be_nil
      end

      it "parses required dependency with >= version" do
        dep = parser.parse("some-mod >= 1.2.0")
        expect(dep.mod_name).to eq("some-mod")
        expect(dep.type).to eq(:required)
        expect(dep.version_requirement).not_to be_nil
        expect(dep.version_requirement.operator).to eq(">=")
        expect(dep.version_requirement.version.to_s).to eq("1.2.0")
      end

      it "parses required dependency with = version" do
        dep = parser.parse("exact-mod = 2.0.0")
        expect(dep.mod_name).to eq("exact-mod")
        expect(dep.version_requirement.operator).to eq("=")
      end

      it "parses required dependency with > version" do
        dep = parser.parse("newer-mod > 1.0.0")
        expect(dep.version_requirement.operator).to eq(">")
      end

      it "parses required dependency with <= version" do
        dep = parser.parse("older-mod <= 3.0.0")
        expect(dep.version_requirement.operator).to eq("<=")
      end

      it "parses required dependency with < version" do
        dep = parser.parse("ancient-mod < 0.5.0")
        expect(dep.version_requirement.operator).to eq("<")
      end
    end

    context "with optional dependencies" do
      it "parses optional dependency without version" do
        dep = parser.parse("? optional-mod")
        expect(dep.mod_name).to eq("optional-mod")
        expect(dep.type).to eq(:optional)
        expect(dep.version_requirement).to be_nil
      end

      it "parses optional dependency with version" do
        dep = parser.parse("? optional-mod >= 1.0.0")
        expect(dep.mod_name).to eq("optional-mod")
        expect(dep.type).to eq(:optional)
        expect(dep.version_requirement.operator).to eq(">=")
      end

      it "handles extra whitespace" do
        dep = parser.parse("?  optional-mod  >=  1.0.0  ")
        expect(dep.mod_name).to eq("optional-mod")
        expect(dep.version_requirement.operator).to eq(">=")
      end
    end

    context "with hidden optional dependencies" do
      it "parses hidden optional dependency" do
        dep = parser.parse("(?) hidden-mod")
        expect(dep.mod_name).to eq("hidden-mod")
        expect(dep.type).to eq(:hidden)
        expect(dep.version_requirement).to be_nil
      end

      it "parses hidden optional dependency with version" do
        dep = parser.parse("(?) hidden-mod >= 2.0.0")
        expect(dep.mod_name).to eq("hidden-mod")
        expect(dep.type).to eq(:hidden)
        expect(dep.version_requirement).not_to be_nil
      end
    end

    context "with incompatible dependencies" do
      it "parses incompatible dependency" do
        dep = parser.parse("! bad-mod")
        expect(dep.mod_name).to eq("bad-mod")
        expect(dep.type).to eq(:incompatible)
        expect(dep.version_requirement).to be_nil
      end

      it "parses incompatible dependency with version (ignored per spec)" do
        dep = parser.parse("! bad-mod >= 1.0.0")
        expect(dep.mod_name).to eq("bad-mod")
        expect(dep.type).to eq(:incompatible)
        # Version requirement is parsed but typically ignored for incompatibilities
        expect(dep.version_requirement).not_to be_nil
      end
    end

    context "with load-neutral dependencies" do
      it "parses load-neutral dependency" do
        dep = parser.parse("~ neutral-mod")
        expect(dep.mod_name).to eq("neutral-mod")
        expect(dep.type).to eq(:load_neutral)
        expect(dep.version_requirement).to be_nil
      end

      it "parses load-neutral dependency with version" do
        dep = parser.parse("~ neutral-mod >= 1.5.0")
        expect(dep.mod_name).to eq("neutral-mod")
        expect(dep.type).to eq(:load_neutral)
        expect(dep.version_requirement).not_to be_nil
      end
    end

    context "with edge cases" do
      it "handles mod names with hyphens" do
        dep = parser.parse("my-cool-mod >= 1.0.0")
        expect(dep.mod_name).to eq("my-cool-mod")
      end

      it "handles mod names with numbers" do
        dep = parser.parse("mod2 >= 3.0.0")
        expect(dep.mod_name).to eq("mod2")
      end

      it "handles mod names with underscores" do
        dep = parser.parse("my_mod >= 1.0.0")
        expect(dep.mod_name).to eq("my_mod")
      end
    end

    context "with invalid input" do
      it "raises error for nil input" do
        expect { parser.parse(nil) }.to raise_error(ArgumentError, /cannot be nil or empty/)
      end

      it "raises error for empty string" do
        expect { parser.parse("") }.to raise_error(ArgumentError, /cannot be nil or empty/)
      end

      it "raises error for invalid version format" do
        expect { parser.parse("mod >= invalid") }.to raise_error(ArgumentError, /Invalid version requirement/)
      end

      it "raises error for empty mod name" do
        expect { parser.parse(">= 1.0.0") }.to raise_error(ArgumentError, /empty mod name/)
      end

      it "raises error for empty version" do
        expect { parser.parse("mod >= ") }.to raise_error(ArgumentError, /empty version/)
      end
    end

    context "with real-world examples from Factorio" do
      it "parses base MOD dependency" do
        dep = parser.parse("base")
        expect(dep.mod_name).to eq("base")
        expect(dep.required?).to be(true)
      end

      it "parses Space Exploration style dependency" do
        dep = parser.parse("? space-exploration >= 0.6.0")
        expect(dep.mod_name).to eq("space-exploration")
        expect(dep.optional?).to be(true)
      end

      it "parses incompatibility declaration" do
        dep = parser.parse("! conflicting-mod")
        expect(dep.mod_name).to eq("conflicting-mod")
        expect(dep.incompatible?).to be(true)
      end
    end
  end
end
