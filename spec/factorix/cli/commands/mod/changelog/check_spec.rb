# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Changelog::Check do
  let(:command) { Factorix::CLI::Commands::MOD::Changelog::Check.new }
  let(:tmpdir) { Dir.mktmpdir }
  let(:fixtures_dir) { Pathname(__dir__).join("../../../../../fixtures/changelog") }

  after do
    FileUtils.rm_rf(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  describe "#call" do
    it "passes for a valid changelog" do
      changelog_path = fixtures_dir.join("basic.txt")

      result = run_command(command, %W[--changelog=#{changelog_path}])

      expect(result).to be_success
      expect(result.stdout).to include("Changelog is valid")
    end

    it "reports parse error for malformed changelog" do
      changelog_path = File.join(tmpdir, "changelog.txt")
      File.write(changelog_path, "this is not a valid changelog")

      expect {
        run_command(command, %W[--changelog=#{changelog_path}])
      }.to raise_error(Factorix::ValidationError)
    end

    it "reports error when Unreleased section is not at first position" do
      changelog_path = fixtures_dir.join("unreleased_not_first.txt")

      expect {
        run_command(command, %W[--changelog=#{changelog_path}])
      }.to raise_error(Factorix::ValidationError)
    end

    it "reports error for non-descending version order" do
      changelog_path = fixtures_dir.join("wrong_order.txt")

      expect {
        run_command(command, %W[--changelog=#{changelog_path}])
      }.to raise_error(Factorix::ValidationError)
    end

    context "with --release" do
      it "reports error when Unreleased section exists" do
        changelog_path = fixtures_dir.join("with_unreleased.txt")

        expect {
          run_command(command, %W[--release --changelog=#{changelog_path}])
        }.to raise_error(Factorix::ValidationError)
      end

      it "passes when no Unreleased section exists" do
        changelog_path = fixtures_dir.join("basic.txt")
        info_json_path = File.join(tmpdir, "info.json")
        File.write(info_json_path, '{"name":"test-mod","version":"1.1.0","title":"Test","author":"Test"}')

        result = run_command(command, %W[--release --changelog=#{changelog_path} --info-json=#{info_json_path}])

        expect(result).to be_success
        expect(result.stdout).to include("Changelog is valid")
      end

      it "reports error when info.json version does not match first changelog version" do
        changelog_path = fixtures_dir.join("basic.txt")
        info_json_path = File.join(tmpdir, "info.json")
        File.write(info_json_path, '{"name":"test-mod","version":"2.0.0","title":"Test","author":"Test"}')

        expect {
          run_command(command, %W[--release --changelog=#{changelog_path} --info-json=#{info_json_path}])
        }.to raise_error(Factorix::ValidationError)
      end

      it "reports error when info.json is missing" do
        changelog_path = fixtures_dir.join("basic.txt")
        info_json_path = File.join(tmpdir, "nonexistent.json")

        expect {
          run_command(command, %W[--release --changelog=#{changelog_path} --info-json=#{info_json_path}])
        }.to raise_error(Factorix::ValidationError)
      end

      it "passes when info.json version matches first versioned section" do
        changelog_path = fixtures_dir.join("basic.txt")
        info_json_path = File.join(tmpdir, "info.json")
        File.write(info_json_path, '{"name":"test-mod","version":"1.1.0","title":"Test","author":"Test"}')

        result = run_command(command, %W[--release --changelog=#{changelog_path} --info-json=#{info_json_path}])

        expect(result).to be_success
      end
    end
  end
end
