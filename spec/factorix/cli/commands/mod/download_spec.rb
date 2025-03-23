# frozen_string_literal: true

require "digest"
require "dry/cli"
require "fileutils"
require "pathname"
require "tempfile"

require_relative "../../../../../lib/factorix/cli/commands/mod/download"

RSpec.describe Factorix::CLI::Commands::Mod::Download do
  subject(:command) { Factorix::CLI::Commands::Mod::Download.new }

  let(:api) { instance_double(Factorix::ModPortal::API) }
  let(:mod) { instance_double(Factorix::ModPortal::Types::Mod) }
  let(:release) do
    instance_double(
      Factorix::ModPortal::Types::Release,
      version: "1.2.3",
      download_url: URI("https://mods.factorio.com/api/downloads/foo_1.2.3.zip"),
      sha1: "0123456789abcdef0123456789abcdef01234567"
    )
  end
  let(:credential) { instance_double(Factorix::Credential, username: "user", token: "token") }
  let(:downloader) { instance_double(Factorix::Downloader) }
  let(:http_client) { instance_double(Factorix::HttpClient) }
  let(:progress_bar) { instance_double(Factorix::Progress::Bar) }
  let(:sha1_digest) { instance_double(Digest::SHA1, hexdigest: release.sha1) }

  before do
    allow(Factorix::ModPortal::API).to receive(:new).and_return(api)
    allow(api).to receive(:mod).with("foo").and_return(mod)
    allow(mod).to receive(:releases).and_return([release])
    allow(Factorix::Credential).to receive(:new).and_return(credential)
    allow(Factorix::Downloader).to receive(:new).and_return(downloader)
    allow(Factorix::HttpClient).to receive(:new).and_return(http_client)
    allow(Factorix::Progress::Bar).to receive(:new).and_return(progress_bar)
  end

  describe "#call" do
    let(:output_dir) { Pathname(Dir.mktmpdir) }
    let(:output_path) { output_dir / "foo_1.2.3.zip" }

    after do
      FileUtils.remove_entry output_dir
    end

    context "when downloading a mod" do
      before do
        allow(downloader).to receive(:download) do |_url, path|
          File.write(path, "dummy data")
        end
        allow(Digest::SHA1).to receive(:file).with(output_path).and_return(sha1_digest)
      end

      it "downloads the mod" do
        expect { command.call(mod_name: "foo", output_directory: output_dir) }.not_to raise_error
      end

      it "creates the output file" do
        command.call(mod_name: "foo", output_directory: output_dir)
        expect(output_path).to exist
      end

      it "downloads without error when version is specified" do
        expect { command.call(mod_name: "foo", version: "1.2.3", output_directory: output_dir) }.not_to raise_error
      end

      it "creates the output file when version is specified" do
        command.call(mod_name: "foo", version: "1.2.3", output_directory: output_dir)
        expect(output_path).to exist
      end

      # rubocop:disable RSpec/ExampleLength
      it "adds authentication parameters to download URL" do
        expected_url = release.download_url.dup
        expected_url.query = URI.encode_www_form(username: "user", token: "token")
        allow(downloader).to receive(:download).with(expected_url, output_path) do |_url, path|
          File.write(path, "dummy data")
        end

        command.call(mod_name: "foo", output_directory: output_dir)
        expect(downloader).to have_received(:download).with(expected_url, output_path)
      end
      # rubocop:enable RSpec/ExampleLength

      context "with quiet option" do
        it "suppresses output messages" do
          expect { command.call(mod_name: "foo", output_directory: output_dir, quiet: true) }.not_to output.to_stdout
        end
      end
    end

    context "when the file already exists" do
      before do
        FileUtils.touch(output_path)
      end

      it "raises FileExistsError" do
        expect { command.call(mod_name: "foo", output_directory: output_dir) }
          .to raise_error(Factorix::CLI::FileExistsError, "File already exists: #{output_path}")
      end
    end

    context "when SHA1 hash does not match" do
      let(:sha1_digest) { instance_double(Digest::SHA1, hexdigest: "wrong_hash") }

      before do
        allow(downloader).to receive(:download) do |_url, path|
          File.write(path, "wrong data")
        end
        allow(Digest::SHA1).to receive(:file).with(output_path).and_return(sha1_digest)
      end

      it "raises SHA1MismatchError and removes the downloaded file" do
        aggregate_failures do
          expect {
            command.call(mod_name: "foo", output_directory: output_dir)
          }.to raise_error(Factorix::CLI::SHA1MismatchError)
          expect(output_path).not_to exist
        end
      end
    end

    context "when download fails" do
      before do
        allow(downloader).to receive(:download) do |_url, path|
          File.write(path, "partial data")
          raise Factorix::DownloadError, "Download failed"
        end
      end

      it "raises DownloadError and removes the partially downloaded file" do
        aggregate_failures do
          expect {
            command.call(mod_name: "foo", output_directory: output_dir)
          }.to raise_error(Factorix::DownloadError, "Download failed")
          expect(output_path).not_to exist
        end
      end
    end

    context "when specified version does not exist" do
      it "raises an error" do
        expect { command.call(mod_name: "foo", version: "9.9.9", output_directory: output_dir) }
          .to raise_error("No matching release found for version 9.9.9")
      end
    end

    context "when output directory does not exist" do
      let(:non_existent_dir) { Pathname(output_dir) / "non_existent" }

      it "raises DirectoryNotFoundError" do
        expect { command.call(mod_name: "foo", output_directory: non_existent_dir) }
          .to raise_error(Factorix::CLI::DirectoryNotFoundError, "Directory does not exist: #{non_existent_dir}")
      end
    end

    context "when output directory is not writable" do
      before do
        FileUtils.chmod(0444, output_dir)
      end

      after do
        FileUtils.chmod(0755, output_dir)
      end

      it "raises DirectoryNotWritableError" do
        expect { command.call(mod_name: "foo", output_directory: output_dir) }
          .to raise_error(Factorix::CLI::DirectoryNotWritableError, "Directory is not writable: #{output_dir}")
      end
    end
  end
end
