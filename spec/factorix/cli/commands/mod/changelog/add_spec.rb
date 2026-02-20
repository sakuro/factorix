# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Changelog::Add do
  let(:command) { Factorix::CLI::Commands::MOD::Changelog::Add.new }
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  describe "#call" do
    it "creates a new changelog file with the entry" do
      changelog_path = File.join(tmpdir, "changelog.txt")

      result = run_command(command, %W[--version=1.0.0 --category=Features --changelog=#{changelog_path} Added new feature])

      expect(result).to be_success
      content = File.read(changelog_path)
      expect(content).to include("Version: 1.0.0")
      expect(content).to include("  Features:")
      expect(content).to include("    - Added new feature")
    end

    it "adds an entry to an existing changelog file" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      File.write(changelog_path, <<~CHANGELOG)
        #{"-" * 99}
        Version: 1.0.0
          Features:
            - Existing feature
      CHANGELOG

      result = run_command(command, %W[--version=1.0.0 --category=Features --changelog=#{changelog_path} Another feature])

      expect(result).to be_success
      content = File.read(changelog_path)
      expect(content).to include("    - Existing feature")
      expect(content).to include("    - Another feature")
    end

    it "outputs a success message" do
      changelog_path = File.join(tmpdir, "changelog.txt")

      result = run_command(command, %W[--version=1.0.0 --category=Bugfixes --changelog=#{changelog_path} Fixed a bug])

      expect(result.stdout).to include("1.0.0")
      expect(result.stdout).to include("Bugfixes")
    end

    it "raises error for duplicate entries" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      File.write(changelog_path, <<~CHANGELOG)
        #{"-" * 99}
        Version: 1.0.0
          Features:
            - Existing feature
      CHANGELOG

      expect {
        run_command(command, %W[--version=1.0.0 --category=Features --changelog=#{changelog_path} Existing feature])
      }.to raise_error(Factorix::InvalidArgumentError, /duplicate entry/)
    end
  end
end
