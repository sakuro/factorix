# frozen_string_literal: true

require "factorix/mod"

RSpec.describe Factorix::Mod do
  describe "#base?" do
    context "when it is the base with exact case 'base'" do
      subject(:mod) { Factorix::Mod[name: "base"] }

      it "is truthy" do
        expect(mod).to be_base
      end
    end

    context "when it has the name 'BASE' (uppercase)" do
      subject(:mod) { Factorix::Mod[name: "BASE"] }

      it "is falsy" do
        expect(mod).not_to be_base
      end
    end

    context "when it has the name 'Base' (capitalized)" do
      subject(:mod) { Factorix::Mod[name: "Base"] }

      it "is falsy" do
        expect(mod).not_to be_base
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
    context "when comparing by alphabetical order" do
      it "correctly orders a before b" do
        expect(Factorix::Mod[name: "a"]).to be < Factorix::Mod[name: "b"]
      end

      it "correctly orders b after a" do
        expect(Factorix::Mod[name: "b"]).to be > Factorix::Mod[name: "a"]
      end

      it "correctly identifies different mods as not equal" do
        expect(Factorix::Mod[name: "foo"]).not_to eq Factorix::Mod[name: "bar"]
      end

      it "correctly orders mods with special characters" do
        expect(Factorix::Mod[name: "a-mod"]).to be < Factorix::Mod[name: "b-mod"]
      end
    end

    context "when comparing with case sensitivity" do
      it "considers uppercase letters to come before lowercase" do
        expect(Factorix::Mod[name: "A"]).to be < Factorix::Mod[name: "a"]
      end

      it "considers same name with different case as not equal" do
        expect(Factorix::Mod[name: "foo"]).not_to eq Factorix::Mod[name: "Foo"]
      end

      it "correctly orders uppercase before lowercase" do
        expect(Factorix::Mod[name: "FOO"]).to be < Factorix::Mod[name: "foo"]
      end

      it "correctly orders mixed case according to ASCII order" do
        expect(Factorix::Mod[name: "Foo"]).to be < Factorix::Mod[name: "foo"]
      end
    end

    context "when comparing with base mod" do
      it "places base mod before any non-base mod" do
        expect(Factorix::Mod[name: "base"]).to be < Factorix::Mod[name: "a"]
      end

      it "places base mod before non-base mod even if alphabetically later" do
        expect(Factorix::Mod[name: "base"]).to be < Factorix::Mod[name: "a-mod"]
      end

      it "places non-base mod after base mod" do
        expect(Factorix::Mod[name: "a"]).to be > Factorix::Mod[name: "base"]
      end

      it "places non-base mod after base mod even if alphabetically earlier" do
        expect(Factorix::Mod[name: "a-mod"]).to be > Factorix::Mod[name: "base"]
      end

      it "considers two base mods with same name equal" do
        mod1 = Factorix::Mod[name: "base"]
        mod2 = Factorix::Mod[name: "base"]
        expect(mod1).to eq mod2
      end

      it "considers base mod with different case as not equal to base mod" do
        expect(Factorix::Mod[name: "base"]).not_to eq Factorix::Mod[name: "BASE"]
      end

      it "compares Base and base normally (Base is not considered the base mod)" do
        expect(Factorix::Mod[name: "Base"]).to be > Factorix::Mod[name: "base"]
      end

      it "compares BASE and base normally (BASE is not considered the base mod)" do
        expect(Factorix::Mod[name: "BASE"]).to be > Factorix::Mod[name: "base"]
      end
    end
  end
end
