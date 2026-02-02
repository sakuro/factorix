# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Download do
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil) }
  let(:runtime) { instance_double(Factorix::Runtime::MacOS) }
  let(:game_download_api) { instance_double(Factorix::API::GameDownloadAPI) }
  let(:command) { Factorix::CLI::Commands::Download.new(logger:, runtime:, game_download_api:) }

  before do
    allow(runtime).to receive(:class).and_return(Factorix::Runtime::MacOS)
    allow(game_download_api).to receive_messages(latest_version: "2.0.28", resolve_filename: "Factorio_2.0.28.dmg")
    allow(game_download_api).to receive(:download)
  end

  describe "#call" do
    let(:download_dir) { Pathname(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(download_dir)
    end

    context "with default options" do
      it "downloads latest stable alpha for auto-detected platform" do
        run_command(command, ["--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          version: "2.0.28",
          build: "alpha",
          platform: "osx",
          output: download_dir / "Factorio_2.0.28.dmg",
          handler: anything
        )
      end

      it "resolves filename from API" do
        run_command(command, ["--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:resolve_filename).with(
          version: "2.0.28",
          build: "alpha",
          platform: "osx"
        )
      end
    end

    context "with specific version" do
      it "downloads the specified version" do
        run_command(command, ["2.0.73", "--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(version: "2.0.73")
        )
      end

      it "does not call latest_version API" do
        run_command(command, ["2.0.73", "--directory", download_dir.to_s])

        expect(game_download_api).not_to have_received(:latest_version)
      end
    end

    context "with latest version" do
      it "resolves latest version from API" do
        run_command(command, ["latest", "--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:latest_version).with(
          channel: "stable",
          build: "alpha"
        )
      end
    end

    context "with build option" do
      it "uses specified build type" do
        run_command(command, ["--build", "headless", "--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(build: "headless")
        )
      end
    end

    context "with platform option" do
      it "uses specified platform" do
        run_command(command, ["--platform", "linux64", "--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(platform: "linux64")
        )
      end
    end

    context "with channel option" do
      it "resolves version from experimental channel" do
        allow(game_download_api).to receive(:latest_version).with(
          channel: "experimental",
          build: "alpha"
        ).and_return("2.0.29")

        run_command(command, ["--channel", "experimental", "--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:latest_version).with(
          channel: "experimental",
          build: "alpha"
        )
      end
    end

    context "with output option" do
      it "uses specified output filename" do
        run_command(command, ["--output", "custom.dmg", "--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(output: download_dir / "custom.dmg")
        )
      end

      it "does not resolve filename from API" do
        run_command(command, ["--output", "custom.dmg", "--directory", download_dir.to_s])

        expect(game_download_api).not_to have_received(:resolve_filename)
      end
    end

    context "when directory does not exist" do
      it "raises DirectoryNotFoundError" do
        expect {
          run_command(command, ["--directory", "/nonexistent/path"])
        }.to raise_error(Factorix::DirectoryNotFoundError, /does not exist/)
      end
    end

    context "when no version is available" do
      before do
        allow(game_download_api).to receive(:latest_version).and_return(nil)
      end

      it "raises InvalidArgumentError" do
        expect {
          run_command(command, ["latest", "--directory", download_dir.to_s])
        }.to raise_error(Factorix::InvalidArgumentError, /No stable version available/)
      end
    end

    context "with invalid version format" do
      it "raises InvalidArgumentError" do
        expect {
          run_command(command, ["invalid", "--directory", download_dir.to_s])
        }.to raise_error(Factorix::InvalidArgumentError, /Invalid version format/)
      end
    end

    context "with version < 2.0" do
      it "raises InvalidArgumentError" do
        expect {
          run_command(command, ["1.1.107", "--directory", download_dir.to_s])
        }.to raise_error(Factorix::InvalidArgumentError, /not supported.*Minimum version is 2\.0\.0/)
      end
    end
  end

  describe "platform auto-detection" do
    let(:download_dir) { Pathname(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(download_dir)
    end

    context "with MacOS runtime" do
      before do
        allow(runtime).to receive(:class).and_return(Factorix::Runtime::MacOS)
      end

      it "detects osx platform" do
        run_command(command, ["--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(platform: "osx")
        )
      end
    end

    context "with Linux runtime" do
      before do
        allow(runtime).to receive(:class).and_return(Factorix::Runtime::Linux)
      end

      it "detects linux64 platform" do
        run_command(command, ["--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(platform: "linux64")
        )
      end
    end

    context "with Windows runtime" do
      before do
        allow(runtime).to receive(:class).and_return(Factorix::Runtime::Windows)
      end

      it "detects win64 platform" do
        run_command(command, ["--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(platform: "win64")
        )
      end
    end

    context "with WSL runtime" do
      before do
        allow(runtime).to receive(:class).and_return(Factorix::Runtime::WSL)
      end

      it "detects win64 platform" do
        run_command(command, ["--directory", download_dir.to_s])

        expect(game_download_api).to have_received(:download).with(
          hash_including(platform: "win64")
        )
      end
    end
  end
end
