# frozen_string_literal: true

RSpec.describe Factorix::MODDependencyResolver do
  subject(:resolver) { Factorix::MODDependencyResolver.new(logger:) }

  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:download_dir) { Pathname.new("/tmp/downloads") }
  let(:presenter) { instance_double(Factorix::Progress::Presenter, update: nil, finish: nil) }

  describe "#resolve_dependencies" do
    context "with no dependencies" do
      it "returns the same downloads" do
        downloads = [
          {
            release: build_release("mod1", "1.0.0", []),
            output_path: download_dir / "mod1_1.0.0.zip",
            mod_name: "mod1",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          }
        ]

        result = resolver.resolve_dependencies(downloads, download_dir, 4, presenter)

        expect(result).to have_attributes(size: 1)
        expect(result[0][:mod_name]).to eq("mod1")
        expect(result[0][:dependencies_resolved]).to be true
      end
    end

    context "with simple dependency" do
      it "adds the dependency to downloads" do
        # Mock the portal
        allow(Factorix::Application).to receive(:[]).with(:portal).and_return(mock_portal)
        allow(mock_portal).to receive(:get_mod_full).with("mod2").and_return(
          build_mod_info("mod2", "2.0.0", [])
        )

        downloads = [
          {
            release: build_release("mod1", "1.0.0", ["mod2 >= 2.0.0"]),
            output_path: download_dir / "mod1_1.0.0.zip",
            mod_name: "mod1",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          }
        ]

        result = resolver.resolve_dependencies(downloads, download_dir, 4, presenter)

        expect(result).to have_attributes(size: 2)
        expect(result.map {|d| d[:mod_name] }).to contain_exactly("mod1", "mod2")

        mod2_download = result.find {|d| d[:mod_name] == "mod2" }
        expect(mod2_download[:source]).to eq(:dependency)
        expect(mod2_download[:dependencies_resolved]).to be true
      end
    end

    context "with recursive dependencies" do
      it "resolves all transitive dependencies" do
        allow(Factorix::Application).to receive(:[]).with(:portal).and_return(mock_portal)

        allow(mock_portal).to receive(:get_mod_full).with("lib1").and_return(
          build_mod_info("lib1", "1.5.0", ["lib2 >= 1.0.0"])
        )
        allow(mock_portal).to receive(:get_mod_full).with("lib2").and_return(
          build_mod_info("lib2", "1.2.0", [])
        )

        downloads = [
          {
            release: build_release("mod1", "1.0.0", ["lib1 >= 1.5.0"]),
            output_path: download_dir / "mod1_1.0.0.zip",
            mod_name: "mod1",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          }
        ]

        result = resolver.resolve_dependencies(downloads, download_dir, 4, presenter)

        expect(result).to have_attributes(size: 3)
        expect(result.map {|d| d[:mod_name] }).to contain_exactly("mod1", "lib1", "lib2")
      end
    end

    context "with version conflict" do
      it "raises an error" do
        downloads = [
          {
            release: build_release("mod1", "1.0.0", ["mod2 >= 3.0.0"]),
            output_path: download_dir / "mod1_1.0.0.zip",
            mod_name: "mod1",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          },
          {
            release: build_release("mod2", "2.0.0", []),
            output_path: download_dir / "mod2_2.0.0.zip",
            mod_name: "mod2",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          }
        ]

        expect {
          resolver.resolve_dependencies(downloads, download_dir, 4, presenter)
        }.to raise_error(ArgumentError, /Version conflict/)
      end
    end

    context "with circular dependency" do
      it "raises an error" do
        allow(Factorix::Application).to receive(:[]).with(:portal).and_return(mock_portal)

        allow(mock_portal).to receive(:get_mod_full).with("mod-b").and_return(
          build_mod_info("mod-b", "1.0.0", ["mod-a"])
        )

        downloads = [
          {
            release: build_release("mod-a", "1.0.0", ["mod-b"]),
            output_path: download_dir / "mod-a_1.0.0.zip",
            mod_name: "mod-a",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          }
        ]

        expect {
          resolver.resolve_dependencies(downloads, download_dir, 4, presenter)
        }.to raise_error(ArgumentError, /Circular dependency/)
      end
    end

    context "with optional dependency" do
      it "skips optional dependencies" do
        downloads = [
          {
            release: build_release("mod1", "1.0.0", ["? optional-mod >= 1.0.0"]),
            output_path: download_dir / "mod1_1.0.0.zip",
            mod_name: "mod1",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          }
        ]

        result = resolver.resolve_dependencies(downloads, download_dir, 4, presenter)

        expect(result).to have_attributes(size: 1)
        expect(result[0][:mod_name]).to eq("mod1")
      end
    end

    context "when dependency resolution fails" do
      it "warns and continues" do
        allow(Factorix::Application).to receive(:[]).with(:portal).and_return(mock_portal)
        allow(mock_portal).to receive(:get_mod_full).with("missing-mod").and_raise(StandardError, "Not found")

        downloads = [
          {
            release: build_release("mod1", "1.0.0", ["missing-mod >= 1.0.0"]),
            output_path: download_dir / "mod1_1.0.0.zip",
            mod_name: "mod1",
            category: Factorix::Types::Category.for("content"),
            version_requirement: nil,
            dependencies_resolved: false,
            source: :explicit
          }
        ]

        result = resolver.resolve_dependencies(downloads, download_dir, 4, presenter)

        expect(logger).to have_received(:error).with(/Failed to fetch dependency/)
        expect(result).to have_attributes(size: 1)
        expect(result[0][:mod_name]).to eq("mod1")
      end
    end
  end

  # Helper methods

  def mock_portal
    @mock_portal ||= instance_double(Factorix::Portal)
  end

  def build_release(name, version, dependencies)
    Factorix::Types::Release.new(
      download_url: "/download/#{name}/#{version}",
      file_name: "#{name}_#{version}.zip",
      info_json: {dependencies:},
      released_at: "2025-01-01T00:00:00.000000Z",
      version:,
      sha1: "abc123",
      feature_flags: []
    )
  end

  def build_mod_info(name, version, dependencies)
    Factorix::Types::MODInfo.new(
      name:,
      title: name.capitalize,
      owner: "test-owner",
      summary: "Test mod",
      downloads_count: 0,
      category: "content",
      score: 0.0,
      thumbnail: nil,
      latest_release: nil,
      releases: [
        {
          download_url: "/download/#{name}/#{version}",
          file_name: "#{name}_#{version}.zip",
          info_json: {dependencies:},
          released_at: "2025-01-01T00:00:00.000000Z",
          version:,
          sha1: "abc123",
          feature_flags: []
        }
      ],
      detail: nil
    )
  end
end
