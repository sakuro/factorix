# frozen_string_literal: true

RSpec.describe Factorix::Cache::Base do
  let(:base) { Factorix::Cache::Base.new }

  describe "#initialize" do
    it "sets default value for ttl" do
      expect(base.ttl).to be_nil
    end

    it "accepts custom ttl" do
      cache = Factorix::Cache::Base.new(ttl: 3600)
      expect(cache.ttl).to eq(3600)
    end
  end

  describe "abstract methods" do
    it "raises NotImplementedError for #exist?" do
      expect { base.exist?("key") }.to raise_error(NotImplementedError, /exist\?/)
    end

    it "raises NotImplementedError for #read" do
      expect { base.read("key") }.to raise_error(NotImplementedError, /read/)
    end

    it "raises NotImplementedError for #store" do
      expect { base.store("key", Pathname("/tmp/file")) }.to raise_error(NotImplementedError, /store/)
    end

    it "raises NotImplementedError for #delete" do
      expect { base.delete("key") }.to raise_error(NotImplementedError, /delete/)
    end

    it "raises NotImplementedError for #clear" do
      expect { base.clear }.to raise_error(NotImplementedError, /clear/)
    end

    it "raises NotImplementedError for #with_lock" do
      expect { base.with_lock("key") { nil } }.to raise_error(NotImplementedError, /with_lock/)
    end

    it "raises NotImplementedError for #age" do
      expect { base.age("key") }.to raise_error(NotImplementedError, /age/)
    end

    it "raises NotImplementedError for #expired?" do
      expect { base.expired?("key") }.to raise_error(NotImplementedError, /expired\?/)
    end

    it "raises NotImplementedError for #size" do
      expect { base.size("key") }.to raise_error(NotImplementedError, /size/)
    end

    it "raises NotImplementedError for #each" do
      expect { base.each }.to raise_error(NotImplementedError, /each/)
    end
  end
end
