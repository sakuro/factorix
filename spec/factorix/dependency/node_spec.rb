# frozen_string_literal: true

RSpec.describe Factorix::Dependency::Node do
  let(:mod) { Factorix::MOD[name: "test-mod"] }
  let(:version) { Factorix::MODVersion.from_string("1.2.3") }

  describe "#initialize" do
    it "creates a node with minimal parameters" do
      node = Factorix::Dependency::Node.new(mod:, version:)

      expect(node.mod).to eq(mod)
      expect(node.version).to eq(version)
      expect(node.enabled).to be false
      expect(node.installed).to be false
      expect(node.operation).to be_nil
    end

    it "creates a node with all parameters" do
      node = Factorix::Dependency::Node.new(
        mod:,
        version:,
        enabled: true,
        installed: true,
        operation: :enable
      )

      expect(node.mod).to eq(mod)
      expect(node.version).to eq(version)
      expect(node.enabled).to be true
      expect(node.installed).to be true
      expect(node.operation).to eq(:enable)
    end
  end

  describe "#enabled?" do
    it "returns true when enabled is true" do
      node = Factorix::Dependency::Node.new(mod:, version:, enabled: true)
      expect(node.enabled?).to be true
    end

    it "returns false when enabled is false" do
      node = Factorix::Dependency::Node.new(mod:, version:, enabled: false)
      expect(node.enabled?).to be false
    end
  end

  describe "#installed?" do
    it "returns true when installed is true" do
      node = Factorix::Dependency::Node.new(mod:, version:, installed: true)
      expect(node.installed?).to be true
    end

    it "returns false when installed is false" do
      node = Factorix::Dependency::Node.new(mod:, version:, installed: false)
      expect(node.installed?).to be false
    end
  end

  describe "#operation?" do
    it "returns true when operation is set" do
      node = Factorix::Dependency::Node.new(mod:, version:, operation: :enable)
      expect(node.operation?).to be true
    end

    it "returns false when operation is nil" do
      node = Factorix::Dependency::Node.new(mod:, version:, operation: nil)
      expect(node.operation?).to be false
    end
  end

  describe "attribute setters" do
    let(:node) { Factorix::Dependency::Node.new(mod:, version:) }

    it "allows changing enabled state" do
      node.enabled = true
      expect(node.enabled).to be true

      node.enabled = false
      expect(node.enabled).to be false
    end

    it "allows changing installed state" do
      node.installed = true
      expect(node.installed).to be true

      node.installed = false
      expect(node.installed).to be false
    end

    it "allows changing operation" do
      node.operation = :enable
      expect(node.operation).to eq(:enable)

      node.operation = :disable
      expect(node.operation).to eq(:disable)

      node.operation = nil
      expect(node.operation).to be_nil
    end
  end

  describe "#to_s" do
    it "shows new state when no flags are set" do
      node = Factorix::Dependency::Node.new(mod:, version:)
      expect(node.to_s).to eq("test-mod v1.2.3 (new)")
    end

    it "shows enabled state" do
      node = Factorix::Dependency::Node.new(mod:, version:, enabled: true)
      expect(node.to_s).to eq("test-mod v1.2.3 (enabled)")
    end

    it "shows installed state" do
      node = Factorix::Dependency::Node.new(mod:, version:, installed: true)
      expect(node.to_s).to eq("test-mod v1.2.3 (installed)")
    end

    it "shows operation when set" do
      node = Factorix::Dependency::Node.new(mod:, version:, operation: :enable)
      expect(node.to_s).to eq("test-mod v1.2.3 (op:enable)")
    end

    it "shows combined states" do
      node = Factorix::Dependency::Node.new(
        mod:,
        version:,
        enabled: true,
        installed: true,
        operation: :disable
      )
      expect(node.to_s).to eq("test-mod v1.2.3 (enabled, installed, op:disable)")
    end
  end

  describe "#inspect" do
    it "includes class name and to_s output" do
      node = Factorix::Dependency::Node.new(mod:, version:, enabled: true)
      expect(node.inspect).to match(/^#<Factorix::Dependency::Node test-mod v1\.2\.3 \(enabled\)>$/)
    end
  end
end
