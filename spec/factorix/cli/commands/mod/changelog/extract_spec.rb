# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Changelog::Extract do
  let(:command) { Factorix::CLI::Commands::MOD::Changelog::Extract.new }
  let(:fixtures_dir) { Pathname(__dir__).join("../../../../../fixtures/changelog") }

  describe "#call" do
    it "outputs plain text for an existing version" do
      result = run_command(command, %W[--version=1.0.0 --changelog=#{fixtures_dir.join("basic.txt")}])

      expect(result).to be_success
      expect(result.stdout).to include("Version: 1.0.0")
      expect(result.stdout).to include("  Features:")
      expect(result.stdout).to include("    - Initial release")
    end

    it "outputs JSON for an existing version" do
      result = run_command(command, %W[--version=2.0.0 --json --changelog=#{fixtures_dir.join("with_date.txt")}])

      expect(result).to be_success
      json = JSON.parse(result.stdout)
      expect(json["version"]).to eq("2.0.0")
      expect(json["date"]).to eq("2025-01-15")
      expect(json["entries"]).to eq("Features" => ["Major overhaul"])
    end

    it "raises error when version not found" do
      expect {
        run_command(command, %W[--version=9.9.9 --changelog=#{fixtures_dir.join("basic.txt")}])
      }.to raise_error(Factorix::InvalidArgumentError, /version not found/)
    end

    it "extracts the Unreleased section" do
      result = run_command(command, %W[--version=Unreleased --changelog=#{fixtures_dir.join("with_unreleased.txt")}])

      expect(result).to be_success
      expect(result.stdout).to include("Version: Unreleased")
      expect(result.stdout).to include("  Features:")
      expect(result.stdout).to include("    - Added new experimental feature")
      expect(result.stdout).to include("  Bugfixes:")
      expect(result.stdout).to include("    - Fixed edge case in parser")
    end

    it "includes date in plain text output when present" do
      result = run_command(command, %W[--version=2.0.0 --changelog=#{fixtures_dir.join("with_date.txt")}])

      expect(result).to be_success
      expect(result.stdout).to include("Date: 2025-01-15")
    end

    it "omits date in plain text output when absent" do
      result = run_command(command, %W[--version=1.0.0 --changelog=#{fixtures_dir.join("basic.txt")}])

      expect(result).to be_success
      expect(result.stdout).not_to include("Date:")
    end
  end
end
