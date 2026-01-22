# frozen_string_literal: true

# Shared context for tests that need test cache backends.
# Uses Container stubbing to provide TestBackend instances.
#
# @example Use with test caches
#   describe "cache operations", :with_test_caches do
#     # download_cache, api_cache, info_json_cache are available as let variables
#   end
#
# @example Access the test cache
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

  after do
    Factorix::Container.unstub(:download_cache)
    Factorix::Container.unstub(:api_cache)
    Factorix::Container.unstub(:info_json_cache)
  end
end

RSpec.configure do |config|
  config.include_context "with test caches", :with_test_caches
end
