# frozen_string_literal: true

require "tmpdir"

RSpec.describe Factorix::CLI::Commands::MOD::Download do
  let(:portal) { instance_double(Factorix::Portal) }
  let(:logger) { instance_double(Dry::Logger::Dispatcher, debug: nil, info: nil, warn: nil, error: nil) }
  let(:runtime) { instance_double(Factorix::Runtime::Base, mod_dir: Pathname("/fake/mods")) }
  let(:downloader) { instance_double(Factorix::Transfer::Downloader) }
  let(:command) { Factorix::CLI::Commands::MOD::Download.new(portal:, logger:, runtime:) }
  let(:mod_info) do
    Factorix::API::MODInfo.new(
      name: "test-mod",
      title: "Test MOD",
      owner: "test-owner",
      summary: "Test MOD",
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
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)
    allow(Factorix::Container).to receive(:[]).with(:logger).and_return(logger)
    allow(portal).to receive(:get_mod_full).with("test-mod").and_return(mod_info)
    allow(portal).to receive(:download_mod)
    allow(downloader).to receive(:subscribe)
    allow(downloader).to receive(:unsubscribe)

    mod_download_api = instance_double(Factorix::API::MODDownloadAPI)
    allow(portal).to receive(:mod_download_api).and_return(mod_download_api)
    allow(mod_download_api).to receive(:downloader).and_return(downloader)
  end

  describe "#call" do
    it "downloads a single MOD" do
      run_command(command, %W[test-mod --directory=#{tmpdir} --jobs=1])

      expect(portal).to have_received(:get_mod_full).with("test-mod")
      expect(portal).to have_received(:download_mod).once
    end

    it "raises error if download directory does not exist" do
      download_dir = File.join(tmpdir, "nonexistent")

      expect {
        run_command(command, %W[test-mod --directory=#{download_dir} --jobs=1])
      }.to raise_error(Factorix::Error, /Download directory does not exist/)
    end

    it "handles MOD with version specification" do
      run_command(command, %W[test-mod@1.0.0 --directory=#{tmpdir} --jobs=1])

      expect(portal).to have_received(:get_mod_full).with("test-mod")
      expect(portal).to have_received(:download_mod).once
    end

    it "handles latest version specification" do
      run_command(command, %W[test-mod@latest --directory=#{tmpdir} --jobs=1])

      expect(portal).to have_received(:get_mod_full).with("test-mod")
      expect(portal).to have_received(:download_mod).once
    end

    it "downloads multiple mods" do
      mod1_info = Factorix::API::MODInfo.new(
        name: "mod1",
        title: "MOD 1",
        owner: "test-owner",
        summary: "Test MOD 1",
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
      mod2_info = Factorix::API::MODInfo.new(
        name: "mod2",
        title: "MOD 2",
        owner: "test-owner",
        summary: "Test MOD 2",
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

      run_command(command, %W[mod1 mod2 --directory=#{tmpdir} --jobs=2])

      expect(portal).to have_received(:get_mod_full).with("mod1")
      expect(portal).to have_received(:get_mod_full).with("mod2")
      expect(portal).to have_received(:download_mod).twice
    end

    context "with invalid MOD specification" do
      it "raises error for non-existent release version" do
        expect {
          run_command(command, %W[test-mod@9.9.9 --directory=#{tmpdir} --jobs=1])
        }.to raise_error(Factorix::Error, /Release not found/)
      end
    end

    context "with MOD directory as download target" do
      let(:runtime) { instance_double(Factorix::Runtime::Base, mod_dir: Pathname(tmpdir).expand_path) }

      it "raises error when trying to download to MOD directory" do
        expect {
          run_command(command, %W[test-mod --directory=#{tmpdir} --jobs=1])
        }.to raise_error(Factorix::Error, /Cannot download to MOD directory/)
      end

      it "raises error when using '.' in MOD directory" do
        Dir.chdir(runtime.mod_dir) do
          expect {
            run_command(command, %w[test-mod --directory=. --jobs=1])
          }.to raise_error(Factorix::Error, /Cannot download to MOD directory/)
        end
      end
    end

    context "with invalid filename" do
      let(:mod_info_with_bad_filename) do
        Factorix::API::MODInfo.new(
          name: "evil-mod",
          title: "Evil MOD",
          owner: "test-owner",
          summary: "Evil MOD",
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
          run_command(command, %W[evil-mod --directory=#{tmpdir} --jobs=1])
        }.to raise_error(Factorix::InvalidArgumentError, /path/)
      end
    end
  end

  describe "#parse_mod_spec" do
    it "parses MOD name without version" do
      result = command.__send__(:parse_mod_spec, "test-mod")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(:latest)
    end

    it "parses MOD name with version" do
      result = command.__send__(:parse_mod_spec, "test-mod@1.2.3")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(Factorix::MODVersion.from_string("1.2.3"))
    end

    it "parses MOD name with @latest" do
      result = command.__send__(:parse_mod_spec, "test-mod@latest")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(:latest)
    end

    it "parses MOD name with empty version as latest" do
      result = command.__send__(:parse_mod_spec, "test-mod@")
      expect(result[:mod].name).to eq("test-mod")
      expect(result[:version]).to eq(:latest)
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
      }.to raise_error(Factorix::InvalidArgumentError, /empty/)
    end

    it "rejects nil filename" do
      expect {
        command.__send__(:validate_filename, nil)
      }.to raise_error(Factorix::InvalidArgumentError, /empty/)
    end

    it "rejects filename with path separator" do
      expect {
        command.__send__(:validate_filename, "path/to/file.zip")
      }.to raise_error(Factorix::InvalidArgumentError, /separator/)
    end

    it "rejects filename with parent directory reference" do
      expect {
        command.__send__(:validate_filename, "..evil.zip")
      }.to raise_error(Factorix::InvalidArgumentError, /parent directory/)
    end
  end

  describe "with --recursive option" do
    let(:mod_with_dep) do
      Factorix::API::MODInfo.new(
        name: "mod-with-dep",
        title: "MOD With Dependency",
        owner: "test-owner",
        summary: "Test MOD with dependency",
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
      Factorix::API::MODInfo.new(
        name: "dep-mod",
        title: "Dependency MOD",
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

        allow(portal).to receive(:get_mod_full).with("mod-with-dep").and_return(mod_with_dep)
        allow(portal).to receive(:get_mod_full).with("dep-mod").and_return(dep_mod)
        allow(portal).to receive(:download_mod).and_return(true)

        # Stub Progress::Presenter to avoid tty-progressbar issues in test environment
        presenter = instance_double(Factorix::Progress::Presenter, start: nil, update: nil, increase_total: nil)
        allow(Factorix::Progress::Presenter).to receive(:new).and_return(presenter)

        run_command(command, %W[mod-with-dep --directory=#{tmpdir} --jobs=1 --recursive])

        # Verify both mods were downloaded
        expect(portal).to have_received(:download_mod).twice
      end
    end

    it "does not download dependencies when --recursive is false" do
      Dir.mktmpdir do |tmpdir|
        Pathname.new(tmpdir)

        allow(portal).to receive(:get_mod_full).with("mod-with-dep").and_return(mod_with_dep)
        allow(portal).to receive(:download_mod).and_return(true)

        run_command(command, %W[mod-with-dep --directory=#{tmpdir} --jobs=1])

        # Verify only the specified mod was downloaded
        expect(portal).to have_received(:download_mod).once
      end
    end
  end
end
