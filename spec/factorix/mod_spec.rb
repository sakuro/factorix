# frozen_string_literal: true

require "factorix/mod"

RSpec.describe Factorix::Mod do
  describe "#base?" do
    context "when it is the base" do
      subject(:mod) { Factorix::Mod[name: "base"] }

      it "is truthy" do
        expect(mod).to be_base
      end
    end

    context "when it is not the base" do
      subject(:mod) { Factorix::Mod[name: "space-age"] }

      it "is falsy" do
        expect(mod).not_to be_base
      end
    end
  end

  describe "#<=>" do
    it "can be compared by case insensitive name" do
      aggregate_failures do
        expect(Factorix::Mod[name: "BAR"] < Factorix::Mod[name: "foo"]).to be_truthy
        expect(Factorix::Mod[name: "foo"] == Factorix::Mod[name: "Foo"]).to be_truthy
        expect(Factorix::Mod[name: "foo"] != Factorix::Mod[name: "bar"]).to be_truthy
        expect(Factorix::Mod[name: "foo"] > Factorix::Mod[name: "Bar"]).to be_truthy
      end
    end

    context "when self is base" do
      it "comes always before non-base" do
        expect(Factorix::Mod[name: "base"] < Factorix::Mod[name: "a"]).to be_truthy
      end
    end

    context "when self is non-base" do
      it "is always bigger than base" do
        expect(Factorix::Mod[name: "a"] > Factorix::Mod[name: "base"]).to be_truthy
      end
    end
  end
end
