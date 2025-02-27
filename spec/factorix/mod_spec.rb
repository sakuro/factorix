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
    it "compares BAR and foo" do
      expect(Factorix::Mod[name: "BAR"]).to be < Factorix::Mod[name: "foo"]
    end

    it "compares foo and Foo" do
      expect(Factorix::Mod[name: "foo"]).to eq Factorix::Mod[name: "Foo"]
    end

    it "compares foo and bar" do
      expect(Factorix::Mod[name: "foo"]).not_to eq Factorix::Mod[name: "bar"]
    end

    it "compares foo and Bar" do
      expect(Factorix::Mod[name: "foo"]).to be > Factorix::Mod[name: "Bar"]
    end

    context "when self is base" do
      it "comes always before non-base" do
        expect(Factorix::Mod[name: "base"]).to be < Factorix::Mod[name: "a"]
      end
    end

    context "when self is non-base" do
      it "is always bigger than base" do
        expect(Factorix::Mod[name: "a"]).to be > Factorix::Mod[name: "base"]
      end
    end
  end
end
