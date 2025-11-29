# frozen_string_literal: true

RSpec.describe Factorix::API::Category do
  describe ".for" do
    context "with known category values" do
      it "returns predefined instance for content" do
        category = Factorix::API::Category.for("content")
        expect(category.value).to eq("content")
        expect(category.name).to eq("Content")
        expect(category.description).to eq("Mods introducing new content into the game")
      end

      it "returns predefined instance for utilities" do
        category = Factorix::API::Category.for("utilities")
        expect(category.value).to eq("utilities")
        expect(category.name).to eq("Utilities")
      end

      it "returns predefined instance for no-category" do
        category = Factorix::API::Category.for("no-category")
        expect(category.value).to eq("")
        expect(category.name).to eq("No category")
      end

      it "returns predefined instance for empty string" do
        category = Factorix::API::Category.for("")
        expect(category.value).to eq("")
        expect(category.name).to eq("No category")
      end
    end

    context "with flyweight pattern" do
      it "returns same instance for same category value" do
        category1 = Factorix::API::Category.for("content")
        category2 = Factorix::API::Category.for("content")
        expect(category1).to be(category2)
      end

      it "returns same instance for no-category and empty string" do
        category1 = Factorix::API::Category.for("no-category")
        category2 = Factorix::API::Category.for("")
        expect(category1).to be(category2)
      end
    end

    context "with unknown category value" do
      it "raises KeyError" do
        expect {
          Factorix::API::Category.for("unknown-category")
        }.to raise_error(KeyError)
      end
    end
  end

  describe "private constructors" do
    it "does not allow direct instantiation via new" do
      expect {
        Factorix::API::Category.new(value: "test", name: "Test", description: "Test")
      }.to raise_error(NoMethodError, /private method/)
    end

    it "does not allow direct instantiation via []" do
      expect {
        Factorix::API::Category[value: "test", name: "Test", description: "Test"]
      }.to raise_error(NoMethodError, /private method/)
    end
  end
end
