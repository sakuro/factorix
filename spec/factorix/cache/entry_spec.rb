# frozen_string_literal: true

RSpec.describe Factorix::Cache::Entry do
  describe ".new" do
    it "creates an entry with size, age, and expired attributes" do
      entry = Factorix::Cache::Entry.new(size: 1024, age: 3600.5, expired: false)

      expect(entry.size).to eq(1024)
      expect(entry.age).to eq(3600.5)
      expect(entry.expired).to be false
    end

    it "creates an expired entry" do
      entry = Factorix::Cache::Entry.new(size: 512, age: 7200.0, expired: true)

      expect(entry.expired).to be true
    end
  end

  describe "#==" do
    it "considers entries with same attributes equal" do
      entry1 = Factorix::Cache::Entry.new(size: 100, age: 50.0, expired: false)
      entry2 = Factorix::Cache::Entry.new(size: 100, age: 50.0, expired: false)

      expect(entry1).to eq(entry2)
    end

    it "considers entries with different attributes not equal" do
      entry1 = Factorix::Cache::Entry.new(size: 100, age: 50.0, expired: false)
      entry2 = Factorix::Cache::Entry.new(size: 200, age: 50.0, expired: false)

      expect(entry1).not_to eq(entry2)
    end
  end

  describe "#with" do
    it "creates a new entry with updated attributes" do
      entry = Factorix::Cache::Entry.new(size: 100, age: 50.0, expired: false)
      new_entry = entry.with(expired: true)

      expect(new_entry.size).to eq(100)
      expect(new_entry.age).to eq(50.0)
      expect(new_entry.expired).to be true
      expect(entry.expired).to be false
    end
  end

  describe "#deconstruct_keys" do
    it "supports pattern matching" do
      entry = Factorix::Cache::Entry.new(size: 1024, age: 100.0, expired: true)

      case entry
      in {size: s, expired: true}
        expect(s).to eq(1024)
      else
        raise RuntimeError, "Pattern should have matched"
      end
    end
  end
end
