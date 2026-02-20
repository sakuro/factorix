# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Changelog::Release do
  let(:command) { Factorix::CLI::Commands::MOD::Changelog::Release.new }
  let(:tmpdir) { Dir.mktmpdir }
  let(:fixtures_dir) { Pathname(__dir__).join("../../../../../fixtures/changelog") }

  after do
    FileUtils.rm_rf(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  describe "#call" do
    it "releases Unreleased section with specified version and date" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      FileUtils.cp(fixtures_dir.join("with_unreleased.txt"), changelog_path)

      result = run_command(command, %W[--version=1.1.0 --date=2025-06-15 --changelog=#{changelog_path}])

      expect(result).to be_success
      expect(result.stdout).to include("Released 1.1.0 (2025-06-15)")

      content = File.read(changelog_path)
      expect(content).to include("Version: 1.1.0")
      expect(content).to include("Date: 2025-06-15")
      expect(content).not_to include("Unreleased")
    end

    it "defaults version to info.json version when --version is omitted" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      FileUtils.cp(fixtures_dir.join("with_unreleased.txt"), changelog_path)
      info_json_path = File.join(tmpdir, "info.json")
      File.write(info_json_path, '{"name":"test-mod","version":"2.0.0","title":"Test","author":"Test"}')

      result = run_command(command, %W[--date=2025-06-15 --changelog=#{changelog_path} --info-json=#{info_json_path}])

      expect(result).to be_success
      expect(result.stdout).to include("Released 2.0.0 (2025-06-15)")
    end

    it "defaults date to today UTC when --date is omitted" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      FileUtils.cp(fixtures_dir.join("with_unreleased.txt"), changelog_path)
      today = Time.now.utc.strftime("%Y-%m-%d")

      result = run_command(command, %W[--version=1.1.0 --changelog=#{changelog_path}])

      expect(result).to be_success
      expect(result.stdout).to include("Released 1.1.0 (#{today})")
    end

    it "raises error when first section is not Unreleased" do
      changelog_path = fixtures_dir.join("basic.txt").to_s
      tmp_changelog = File.join(tmpdir, "changelog.txt")
      FileUtils.cp(changelog_path, tmp_changelog)

      expect {
        run_command(command, %W[--version=2.0.0 --date=2025-06-15 --changelog=#{tmp_changelog}])
      }.to raise_error(Factorix::InvalidOperationError, /First section is not Unreleased/)
    end

    it "raises error when target version already exists in changelog" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      FileUtils.cp(fixtures_dir.join("with_unreleased.txt"), changelog_path)

      expect {
        run_command(command, %W[--version=1.0.0 --date=2025-06-15 --changelog=#{changelog_path}])
      }.to raise_error(Factorix::InvalidOperationError, /Version 1.0.0 already exists/)
    end

    it "raises error for invalid version string" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      FileUtils.cp(fixtures_dir.join("with_unreleased.txt"), changelog_path)

      expect {
        run_command(command, %W[--version=invalid --date=2025-06-15 --changelog=#{changelog_path}])
      }.to raise_error(Factorix::VersionParseError)
    end
  end
end
