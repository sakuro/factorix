# frozen_string_literal: true

# Shared context that provides TestBackend instances for all tests.
# Every test gets fresh cache instances via let variables.
#
# @example Access the test cache directly
#   it "stores entries" do
#     download_cache.add_entry("key", "content")
#     expect(download_cache.exist?("key")).to be true
#   end
RSpec.shared_context "with test caches" do
  let(:download_cache) { Factorix::Cache::TestBackend.new(ttl: nil) }
  let(:api_cache) { Factorix::Cache::TestBackend.new(ttl: 3600) }
  let(:info_json_cache) { Factorix::Cache::TestBackend.new(ttl: nil) }

  before do
    Factorix::Container.stub(:download_cache, download_cache)
    Factorix::Container.stub(:api_cache, api_cache)
    Factorix::Container.stub(:info_json_cache, info_json_cache)
  end
end

RSpec.configure do |config|
  config.include_context "with test caches"
end
