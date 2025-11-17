# frozen_string_literal: true

RSpec.describe Factorix::Dependency::ValidationResult do
  let(:mod_a) { Factorix::MOD[name: "mod-a"] }
  let(:mod_b) { Factorix::MOD[name: "mod-b"] }

  describe "#initialize" do
    it "creates empty result" do
      result = Factorix::Dependency::ValidationResult.new

      expect(result.errors).to be_empty
      expect(result.warnings).to be_empty
      expect(result.valid?).to be true
    end
  end

  describe "#add_error" do
    it "adds an error" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_error(
        type: :missing_dependency,
        message: "Missing dependency",
        mod: mod_a,
        dependency: mod_b
      )

      expect(result.errors.size).to eq(1)
      error = result.errors.first
      expect(error.type).to eq(:missing_dependency)
      expect(error.message).to eq("Missing dependency")
      expect(error.mod).to eq(mod_a)
      expect(error.dependency).to eq(mod_b)
    end

    it "adds error without optional parameters" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_error(
        type: :circular_dependency,
        message: "Circular dependency detected"
      )

      error = result.errors.first
      expect(error.type).to eq(:circular_dependency)
      expect(error.message).to eq("Circular dependency detected")
      expect(error.mod).to be_nil
      expect(error.dependency).to be_nil
    end
  end

  describe "#add_warning" do
    it "adds a warning" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_warning(
        type: :mod_in_list_not_installed,
        message: "MOD in list but not installed",
        mod: mod_a
      )

      expect(result.warnings.size).to eq(1)
      warning = result.warnings.first
      expect(warning.type).to eq(:mod_in_list_not_installed)
      expect(warning.message).to eq("MOD in list but not installed")
      expect(warning.mod).to eq(mod_a)
    end

    it "adds warning without optional parameters" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_warning(
        type: :mod_installed_not_in_list,
        message: "MOD installed but not in list"
      )

      warning = result.warnings.first
      expect(warning.type).to eq(:mod_installed_not_in_list)
      expect(warning.message).to eq("MOD installed but not in list")
      expect(warning.mod).to be_nil
    end
  end

  describe "#errors?" do
    it "returns false when no errors" do
      result = Factorix::Dependency::ValidationResult.new
      expect(result.errors?).to be false
    end

    it "returns true when errors exist" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_error(type: :missing_dependency, message: "Error")
      expect(result.errors?).to be true
    end
  end

  describe "#warnings?" do
    it "returns false when no warnings" do
      result = Factorix::Dependency::ValidationResult.new
      expect(result.warnings?).to be false
    end

    it "returns true when warnings exist" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_warning(type: :mod_in_list_not_installed, message: "Warning")
      expect(result.warnings?).to be true
    end
  end

  describe "#valid?" do
    it "returns true when no errors" do
      result = Factorix::Dependency::ValidationResult.new
      expect(result.valid?).to be true
    end

    it "returns true when only warnings exist" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_warning(type: :mod_in_list_not_installed, message: "Warning")
      expect(result.valid?).to be true
    end

    it "returns false when errors exist" do
      result = Factorix::Dependency::ValidationResult.new
      result.add_error(type: :missing_dependency, message: "Error")
      expect(result.valid?).to be false
    end
  end

  describe "constants" do
    it "defines error type constants" do
      expect(Factorix::Dependency::ValidationResult::MISSING_DEPENDENCY).to eq(:missing_dependency)
      expect(Factorix::Dependency::ValidationResult::DISABLED_DEPENDENCY).to eq(:disabled_dependency)
      expect(Factorix::Dependency::ValidationResult::VERSION_MISMATCH).to eq(:version_mismatch)
      expect(Factorix::Dependency::ValidationResult::CONFLICT).to eq(:conflict)
      expect(Factorix::Dependency::ValidationResult::CIRCULAR_DEPENDENCY).to eq(:circular_dependency)
    end

    it "defines warning type constants" do
      expect(Factorix::Dependency::ValidationResult::MOD_IN_LIST_NOT_INSTALLED).to eq(:mod_in_list_not_installed)
      expect(Factorix::Dependency::ValidationResult::MOD_INSTALLED_NOT_IN_LIST).to eq(:mod_installed_not_in_list)
    end
  end
end
