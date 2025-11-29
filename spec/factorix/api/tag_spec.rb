# frozen_string_literal: true

RSpec.describe Factorix::API::Tag do
  describe ".for" do
    context "with known tag values" do
      it "returns predefined instance for transportation" do
        tag = Factorix::API::Tag.for("transportation")
        expect(tag.value).to eq("transportation")
        expect(tag.name).to eq("Transportation")
        expect(tag.description).to eq("Transportation of the player, be it vehicles or teleporters.")
      end

      it "returns predefined instance for logistics" do
        tag = Factorix::API::Tag.for("logistics")
        expect(tag.value).to eq("logistics")
        expect(tag.name).to eq("Logistics")
        expect(tag.description).to eq("Augmented or new ways of transporting materials - belts, inserters, pipes!")
      end

      it "returns predefined instance for combat" do
        tag = Factorix::API::Tag.for("combat")
        expect(tag.value).to eq("combat")
        expect(tag.name).to eq("Combat")
      end

      it "returns predefined instance for logistic-network" do
        tag = Factorix::API::Tag.for("logistic-network")
        expect(tag.value).to eq("logistic-network")
        expect(tag.name).to eq("Logistics Network")
      end

      it "returns predefined instance for circuit-network" do
        tag = Factorix::API::Tag.for("circuit-network")
        expect(tag.value).to eq("circuit-network")
        expect(tag.name).to eq("Circuit network")
      end
    end

    context "with flyweight pattern" do
      it "returns same instance for same tag value" do
        tag1 = Factorix::API::Tag.for("transportation")
        tag2 = Factorix::API::Tag.for("transportation")
        expect(tag1).to be(tag2)
      end

      it "returns same instance for logistics" do
        tag1 = Factorix::API::Tag.for("logistics")
        tag2 = Factorix::API::Tag.for("logistics")
        expect(tag1).to be(tag2)
      end
    end

    context "with unknown tag value" do
      it "raises KeyError" do
        expect {
          Factorix::API::Tag.for("unknown-tag")
        }.to raise_error(KeyError)
      end
    end
  end

  describe "private constructors" do
    it "does not allow direct instantiation via new" do
      expect {
        Factorix::API::Tag.new(value: "test", name: "Test", description: "Test")
      }.to raise_error(NoMethodError, /private method/)
    end

    it "does not allow direct instantiation via []" do
      expect {
        Factorix::API::Tag[value: "test", name: "Test", description: "Test"]
      }.to raise_error(NoMethodError, /private method/)
    end
  end
end
