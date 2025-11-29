# frozen_string_literal: true

RSpec.describe Factorix::MODState do
  describe "#initialize" do
    it "creates a MODState with enabled flag only" do
      state = Factorix::MODState[enabled: true]
      expect(state.enabled).to be(true)
      expect(state.version).to be_nil
    end

    it "creates a MODState with enabled and version" do
      version = Factorix::MODVersion.from_string("1.2.3")
      state = Factorix::MODState[enabled: false, version:]
      expect(state.enabled).to be(false)
      expect(state.version).to eq(version)
    end
  end

  describe "#enabled" do
    it "returns the enabled flag" do
      state = Factorix::MODState[enabled: true]
      expect(state.enabled).to be(true)
    end
  end

  describe "#enabled?" do
    it "returns true when enabled" do
      state = Factorix::MODState[enabled: true]
      expect(state.enabled?).to be(true)
    end

    it "returns false when disabled" do
      state = Factorix::MODState[enabled: false]
      expect(state.enabled?).to be(false)
    end
  end

  describe "#version" do
    it "returns the version" do
      version = Factorix::MODVersion.from_string("1.0.0")
      state = Factorix::MODState[enabled: true, version:]
      expect(state.version).to eq(version)
    end

    it "returns nil when version is not set" do
      state = Factorix::MODState[enabled: true]
      expect(state.version).to be_nil
    end
  end

  describe "equality" do
    let(:version) { Factorix::MODVersion.from_string("1.2.3") }

    it "considers two MODStates with same values as equal" do
      state1 = Factorix::MODState[enabled: true, version:]
      state2 = Factorix::MODState[enabled: true, version:]
      expect(state1).to eq(state2)
    end

    it "considers two MODStates with different enabled values as not equal" do
      state1 = Factorix::MODState[enabled: true, version:]
      state2 = Factorix::MODState[enabled: false, version:]
      expect(state1).not_to eq(state2)
    end

    it "considers two MODStates with different versions as not equal" do
      other_version = Factorix::MODVersion.from_string("2.0.0")
      state1 = Factorix::MODState[enabled: true, version:]
      state2 = Factorix::MODState[enabled: true, version: other_version]
      expect(state1).not_to eq(state2)
    end
  end

  describe "immutability" do
    it "is frozen after creation" do
      state = Factorix::MODState[enabled: true]
      expect(state).to be_frozen
    end
  end
end
