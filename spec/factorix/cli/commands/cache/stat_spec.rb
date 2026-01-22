# frozen_string_literal: true

require "json"

RSpec.describe Factorix::CLI::Commands::Cache::Stat, :with_test_caches do
  describe "#call" do
    context "with empty caches" do
      it "outputs statistics in text format" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat)

        expect(result.stdout).to include("download:")
        expect(result.stdout).to include("api:")
        expect(result.stdout).to include("info_json:")
        expect(result.stdout).to include("Entries:        0 / 0")
        expect(result.stdout).to include("Size:           0 B")
      end

      it "outputs statistics in JSON format" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json.keys).to contain_exactly(:download, :api, :info_json)
        expect(json[:download][:entries]).to eq({total: 0, valid: 0, expired: 0})
      end
    end

    context "with cache entries" do
      before do
        download_cache.add_entry("http://example.com/file1", "test content 1")
        download_cache.add_entry("http://example.com/file2", "test content 2 longer")
      end

      it "counts entries correctly" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json[:download][:entries][:total]).to eq(2)
        expect(json[:download][:entries][:valid]).to eq(2)
      end

      it "calculates size statistics" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        expect(json[:download][:size][:total]).to eq(35) # 14 + 21 bytes
        expect(json[:download][:size][:min]).to eq(14)
        expect(json[:download][:size][:max]).to eq(21)
      end
    end

    context "with expired entries" do
      before do
        # Create an old entry (expired) - api cache has TTL of 3600s
        api_cache.add_entry("http://example.com/old", "old content", age: 7200)
        # Create a new entry (valid)
        api_cache.add_entry("http://example.com/new", "new content", age: 0)
      end

      it "distinguishes valid and expired entries" do
        result = run_command(Factorix::CLI::Commands::Cache::Stat, %w[--json])

        json = JSON.parse(result.stdout, symbolize_names: true)
        # api cache has TTL of 3600 seconds (1 hour)
        expect(json[:api][:entries][:total]).to eq(2)
        expect(json[:api][:entries][:valid]).to eq(1)
        expect(json[:api][:entries][:expired]).to eq(1)
      end
    end
  end

  describe "text output formatting" do
    it "formats TTL as duration when set" do
      result = run_command(Factorix::CLI::Commands::Cache::Stat)

      expect(result.stdout).to include("TTL:            1h 0m") # api cache has 3600s TTL
    end

    it "formats TTL as unlimited when nil" do
      result = run_command(Factorix::CLI::Commands::Cache::Stat)

      expect(result.stdout).to include("TTL:            unlimited") # download cache has nil TTL
    end

    it "formats sizes using binary prefixes" do
      download_cache.add_entry("http://example.com/large", "x" * 2048)

      result = run_command(Factorix::CLI::Commands::Cache::Stat)

      expect(result.stdout).to include("KiB")
    end
  end
end
