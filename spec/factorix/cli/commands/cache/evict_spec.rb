# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Cache::Evict, :with_test_caches do
  let(:command) { Factorix::CLI::Commands::Cache::Evict.new }

  describe "#call" do
    context "without any option" do
      it "raises an error" do
        expect { run_command(command) }.to raise_error(Factorix::InvalidArgumentError, /One of --all, --expired, or --older-than must be specified/)
      end
    end

    context "with multiple options" do
      it "raises an error" do
        expect { run_command(command, %w[--all --expired]) }.to raise_error(Factorix::InvalidArgumentError, /Only one of --all, --expired, or --older-than can be specified/)
      end
    end

    context "with --all option" do
      before do
        download_cache.add_entry("http://example.com/file1", "test content 1")
        download_cache.add_entry("http://example.com/file2", "test content 2")
      end

      it "removes all entries" do
        result = run_command(command, %w[--all])

        expect(result.stdout).to match(/download.*2 entries removed/)
        expect(download_cache.each.to_a).to be_empty
      end

      it "respects cache name argument" do
        api_cache.add_entry("http://example.com/api_entry", "api content")

        result = run_command(command, %w[download --all])

        expect(result.stdout).to match(/download/)
        expect(result.stdout).not_to match(/\bapi\s*:/)
        # api cache should still have its entry
        expect(api_cache.exist?("http://example.com/api_entry")).to be true
      end
    end

    context "with --expired option" do
      before do
        # Create an expired entry (older than TTL of 3600s)
        api_cache.add_entry("http://example.com/old", "old content", age: 7200)
        # Create a valid entry
        api_cache.add_entry("http://example.com/new", "new content", age: 0)
      end

      it "removes only expired entries" do
        result = run_command(command, %w[--expired])

        expect(result.stdout).to match(/api.*1 entries removed/)
        expect(api_cache.exist?("http://example.com/old")).to be false
        expect(api_cache.exist?("http://example.com/new")).to be true
      end

      it "does not remove entries from caches without TTL" do
        download_cache.add_entry("http://example.com/old", "old download content", age: 86400) # 1 day old

        result = run_command(command, %w[--expired])

        # download cache has no TTL, so no entries should be removed
        expect(result.stdout).to match(/download.*0 entries removed/)
        expect(download_cache.exist?("http://example.com/old")).to be true
      end
    end

    context "with --older-than option" do
      before do
        # Create an old entry
        download_cache.add_entry("http://example.com/old", "old content", age: 86400) # 1 day old
        # Create a new entry
        download_cache.add_entry("http://example.com/new", "new content", age: 0)
      end

      it "removes entries older than specified age" do
        result = run_command(command, %w[--older-than=12h])

        expect(result.stdout).to match(/download.*1 entries removed/)
        expect(download_cache.exist?("http://example.com/old")).to be false
        expect(download_cache.exist?("http://example.com/new")).to be true
      end

      it "parses various age formats" do
        # Test that parsing works for different formats
        expect { run_command(command, %w[--older-than=30s]) }.not_to raise_error
        expect { run_command(command, %w[--older-than=5m]) }.not_to raise_error
        expect { run_command(command, %w[--older-than=2h]) }.not_to raise_error
        expect { run_command(command, %w[--older-than=7d]) }.not_to raise_error
      end

      it "raises error for invalid age format" do
        expect { run_command(command, %w[--older-than=invalid]) }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
        expect { run_command(command, %w[--older-than=10]) }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
        expect { run_command(command, %w[--older-than=10w]) }.to raise_error(Factorix::InvalidArgumentError, /Invalid age format/)
      end
    end

    context "with unknown cache name" do
      it "exits with error via dry-cli validation" do
        expect { run_command(command, %w[unknown --all]) }.to raise_error(SystemExit)
      end
    end
  end

  describe "output format" do
    before do
      download_cache.add_entry("http://example.com/large", "x" * 2048) # 2 KiB
    end

    it "formats sizes using binary prefixes" do
      result = run_command(command, %w[--all])

      expect(result.stdout).to match(/KiB/)
    end
  end
end
