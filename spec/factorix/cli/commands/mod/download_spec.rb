# frozen_string_literal: true

require "tmpdir"

RSpec.describe Factorix::CLI::Commands::MOD::Download do
  let(:portal) { instance_double(Factorix::Portal) }
  let(:downloader) { instance_double(Factorix::Transfer::Downloader) }
  let(:command) { Factorix::CLI::Commands::MOD::Download.new(portal:) }
  let(:mod_info) do
    Factorix::Types::MODInfo.new(
      name: "test-mod",
      title: "Test Mod",
      owner: "test-owner",
      summary: "Test mod",
      downloads_count: 0,
      category: "utilities",
      score: 0.0,
      thumbnail: nil,
      latest_release: nil,
      releases: [
        {
          download_url: "/download/test-mod/abc123",
          file_name: "test-mod_1.0.0.zip",
          info_json: {
            factorio_version: "2.0",
            dependencies: []
          },
          released_at: "2024-01-01T00:00:00Z",
          version: "1.0.0",
          sha1: "abc123"
        }
      ]
    )
  end

  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  before do
    # Suppress progress bar output
    allow($stdout).to receive(:tty?).and_return(false)
    allow($stderr).to receive(:tty?).and_return(false)

    # Mock the Application container to return the same instances
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)
    allow(portal).to receive(:get_mod_full).with("test-mod").and_return(mod_info)
    allow(portal).to receive(:download_mod)
    allow(downloader).to receive(:subscribe)
    allow(downloader).to receive(:unsubscribe)

    # Mock the downloader chain for download
    mod_download_api = instance_double(Factorix::API::MODDownloadAPI)
    allow(portal).to receive(:mod_download_api).and_return(mod_download_api)
    allow(mod_download_api).to receive(:downloader).and_return(downloader)
  end

  describe "#call" do
    it "downloads a single mod" do
      capture_stdout { command.call(mod_specs: ["test-mod"], directory: tmpdir, jobs: 1) }

      expect(portal).to have_received(:get_mod_full).with("test-mod")
      expect(portal).to have_received(:download_mod).once
    end

    it "creates download directory if it does not exist" do
      download_dir = File.join(tmpdir, "mods")
      capture_stdout { command.call(mod_specs: ["test-mod"], directory: download_dir, jobs: 1) }

      expect(Dir.exist?(download_dir)).to be true
    end

    it "handles mod with version specification" do
      capture_stdout { command.call(mod_specs: ["test-mod@1.0.0"], directory: tmpdir, jobs: 1) }

      expect(portal).to have_received(:get_mod_full).with("test-mod")
      expect(portal).to have_received(:download_mod).once
    end

    it "handles latest version specification" do
      capture_stdout { command.call(mod_specs: ["test-mod@latest"], directory: tmpdir, jobs: 1) }

      expect(portal).to have_received(:get_mod_full).with("test-mod")
      expect(portal).to have_received(:download_mod).once
    end

    it "downloads multiple mods" do
      mod1_info = Factorix::Types::MODInfo.new(
        name: "mod1",
        title: "Mod 1",
        owner: "test-owner",
        summary: "Test mod 1",
        downloads_count: 0,
        category: "content",
        releases: [
          {
            download_url: "/download/mod1/abc1",
            file_name: "mod1_1.0.0.zip",
            info_json: {"factorio_version" => "2.0", "dependencies" => []},
            released_at: "2024-01-01T00:00:00Z",
            version: "1.0.0",
            sha1: "abc1"
          }
        ]
      )
      mod2_info = Factorix::Types::MODInfo.new(
        name: "mod2",
        title: "Mod 2",
        owner: "test-owner",
        summary: "Test mod 2",
        downloads_count: 0,
        category: "tweaks",
        releases: [
          {
            download_url: "/download/mod2/abc2",
            file_name: "mod2_1.0.0.zip",
            info_json: {"factorio_version" => "2.0", "dependencies" => []},
            released_at: "2024-01-01T00:00:00Z",
            version: "1.0.0",
            sha1: "abc2"
          }
        ]
      )

      allow(portal).to receive(:get_mod_full).with("mod1").and_return(mod1_info)
      allow(portal).to receive(:get_mod_full).with("mod2").and_return(mod2_info)

      capture_stdout { command.call(mod_specs: %w[mod1 mod2], directory: tmpdir, jobs: 2) }

      expect(portal).to have_received(:get_mod_full).with("mod1")
      expect(portal).to have_received(:get_mod_full).with("mod2")
      expect(portal).to have_received(:download_mod).twice
    end

    context "with invalid mod specification" do
      it "raises error for non-existent release version" do
        expect {
          capture_stdout { command.call(mod_specs: ["test-mod@9.9.9"], directory: tmpdir, jobs: 1) }
        }.to raise_error(Factorix::Error, /Release not found/)
      end
    end

    context "with invalid filename" do
      let(:mod_info_with_bad_filename) do
        Factorix::Types::MODInfo.new(
          name: "evil-mod",
          title: "Evil Mod",
          owner: "test-owner",
          summary: "Evil mod",
          downloads_count: 0,
          category: "internal",
          releases: [
            {
              download_url: "/download/evil-mod/abc123",
              file_name: "../evil.zip",
              info_json: {"factorio_version" => "2.0", "dependencies" => []},
              released_at: "2024-01-01T00:00:00Z",
              version: "1.0.0",
              sha1: "abc123"
            }
          ]
        )
      end

      it "raises error for path traversal attempt" do
        allow(portal).to receive(:get_mod_full).with("evil-mod").and_return(mod_info_with_bad_filename)

        expect {
          capture_stdout { command.call(mod_specs: ["evil-mod"], directory: tmpdir, jobs: 1) }
        }.to raise_error(ArgumentError, /path/)
      end
    end
  end

  describe "#parse_mod_spec" do
    it "parses mod name without version" do
      name, version = command.__send__(:parse_mod_spec, "test-mod")
      expect(name).to eq("test-mod")
      expect(version).to eq("latest")
    end

    it "parses mod name with version" do
      name, version = command.__send__(:parse_mod_spec, "test-mod@1.2.3")
      expect(name).to eq("test-mod")
      expect(version).to eq("1.2.3")
    end

    it "parses mod name with @latest" do
      name, version = command.__send__(:parse_mod_spec, "test-mod@latest")
      expect(name).to eq("test-mod")
      expect(version).to eq("latest")
    end

    it "parses mod name with empty version as latest" do
      name, version = command.__send__(:parse_mod_spec, "test-mod@")
      expect(name).to eq("test-mod")
      expect(version).to eq("latest")
    end
  end

  describe "#validate_filename" do
    it "accepts valid filename" do
      expect {
        command.__send__(:validate_filename, "test-mod_1.0.0.zip")
      }.not_to raise_error
    end

    it "rejects empty filename" do
      expect {
        command.__send__(:validate_filename, "")
      }.to raise_error(ArgumentError, /empty/)
    end

    it "rejects nil filename" do
      expect {
        command.__send__(:validate_filename, nil)
      }.to raise_error(ArgumentError, /empty/)
    end

    it "rejects filename with path separator" do
      expect {
        command.__send__(:validate_filename, "path/to/file.zip")
      }.to raise_error(ArgumentError, /separator/)
    end

    it "rejects filename with parent directory reference" do
      expect {
        command.__send__(:validate_filename, "..evil.zip")
      }.to raise_error(ArgumentError, /parent directory/)
    end
  end

  describe "with --recursive option" do
    let(:mod_with_dep) do
      Factorix::Types::MODInfo.new(
        name: "mod-with-dep",
        title: "Mod With Dependency",
        owner: "test-owner",
        summary: "Test mod with dependency",
        downloads_count: 0,
        category: "content",
        score: 0.0,
        thumbnail: nil,
        latest_release: nil,
        releases: [
          {
            download_url: "/download/mod-with-dep/1.0.0",
            file_name: "mod-with-dep_1.0.0.zip",
            info_json: {
              factorio_version: "2.0",
              dependencies: ["dep-mod >= 2.0.0"]
            },
            released_at: "2024-01-01T00:00:00Z",
            version: "1.0.0",
            sha1: "abc123"
          }
        ],
        detail: nil
      )
    end

    let(:dep_mod) do
      Factorix::Types::MODInfo.new(
        name: "dep-mod",
        title: "Dependency Mod",
        owner: "test-owner",
        summary: "Dependency",
        downloads_count: 1_000_000,
        category: "content",
        score: 1.0,
        thumbnail: nil,
        latest_release: nil,
        releases: [
          {
            download_url: "/download/dep-mod/2.0.0",
            file_name: "dep-mod_2.0.0.zip",
            info_json: {
              "factorio_version" => "2.0",
              "dependencies" => []
            },
            released_at: "2024-01-01T00:00:00Z",
            version: "2.0.0",
            sha1: "def456"
          }
        ],
        detail: nil
      )
    end

    it "downloads dependencies recursively when --recursive is true" do
      Dir.mktmpdir do |tmpdir|
        Pathname.new(tmpdir)

        # Mock Application container
        logger = instance_double(Logger, info: nil, warn: nil, debug: nil, error: nil)
        allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)
        allow(Factorix::Application).to receive(:[]).with(:logger).and_return(logger)

        # Mock portal responses for both the main mod and its dependency
        allow(portal).to receive(:get_mod_full).with("mod-with-dep").and_return(mod_with_dep)
        allow(portal).to receive(:get_mod_full).with("dep-mod").and_return(dep_mod)
        allow(portal).to receive(:download_mod).and_return(true)

        # Stub Progress::Presenter to avoid tty-progressbar issues in test environment
        presenter = instance_double(Factorix::Progress::Presenter, start: nil, update: nil, increase_total: nil)
        allow(Factorix::Progress::Presenter).to receive(:new).and_return(presenter)

        capture_stdout do
          command.call(
            mod_specs: ["mod-with-dep"],
            directory: tmpdir,
            jobs: 1,
            recursive: true
          )
        end

        # Verify both mods were downloaded
        expect(portal).to have_received(:download_mod).twice
      end
    end

    it "does not download dependencies when --recursive is false" do
      Dir.mktmpdir do |tmpdir|
        Pathname.new(tmpdir)

        # Mock portal response
        allow(portal).to receive(:get_mod_full).with("mod-with-dep").and_return(mod_with_dep)

        # Mock download method
        allow(portal).to receive(:download_mod).and_return(true)

        capture_stdout do
          command.call(
            mod_specs: ["mod-with-dep"],
            directory: tmpdir,
            jobs: 1,
            recursive: false
          )
        end

        # Verify only the specified mod was downloaded
        expect(portal).to have_received(:download_mod).once
      end
    end
  end
end
