# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Edit do
  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Edit.new(portal:) }

  before do
    allow(Factorix::Container).to receive(:[]).and_call_original
    allow(Factorix::Container).to receive(:[]).with(:portal).and_return(portal)
    allow(portal).to receive(:edit_mod)
  end

  describe "#call" do
    it "edits MOD with description" do
      command.call(mod_name: "test-mod", description: "New description")

      expect(portal).to have_received(:edit_mod).with("test-mod", description: "New description")
    end

    it "edits MOD with summary" do
      command.call(mod_name: "test-mod", summary: "Brief summary")

      expect(portal).to have_received(:edit_mod).with("test-mod", summary: "Brief summary")
    end

    it "edits MOD with title" do
      command.call(mod_name: "test-mod", title: "New Title")

      expect(portal).to have_received(:edit_mod).with("test-mod", title: "New Title")
    end

    it "edits MOD with category" do
      command.call(mod_name: "test-mod", category: "utilities")

      expect(portal).to have_received(:edit_mod).with("test-mod", category: "utilities")
    end

    it "edits MOD with tags" do
      command.call(mod_name: "test-mod", tags: %w[combat logistics])

      expect(portal).to have_received(:edit_mod).with("test-mod", tags: %w[combat logistics])
    end

    it "edits MOD with standard license" do
      command.call(mod_name: "test-mod", license: "default_mit")

      expect(portal).to have_received(:edit_mod).with("test-mod", license: "default_mit")
    end

    it "edits MOD with custom license" do
      command.call(mod_name: "test-mod", license: "custom_0123456789abcdef01234567")

      expect(portal).to have_received(:edit_mod).with("test-mod", license: "custom_0123456789abcdef01234567")
    end

    it "edits MOD with homepage" do
      command.call(mod_name: "test-mod", homepage: "https://example.com")

      expect(portal).to have_received(:edit_mod).with("test-mod", homepage: "https://example.com")
    end

    it "edits MOD with source_url" do
      command.call(mod_name: "test-mod", source_url: "https://github.com/user/repo")

      expect(portal).to have_received(:edit_mod).with("test-mod", source_url: "https://github.com/user/repo")
    end

    it "edits MOD with faq" do
      command.call(mod_name: "test-mod", faq: "Q: How?\nA: Easy.")

      expect(portal).to have_received(:edit_mod).with("test-mod", faq: "Q: How?\nA: Easy.")
    end

    it "edits MOD with deprecated flag set to true" do
      command.call(mod_name: "test-mod", deprecated: true)

      expect(portal).to have_received(:edit_mod).with("test-mod", deprecated: true)
    end

    it "edits MOD with deprecated flag set to false" do
      command.call(mod_name: "test-mod", deprecated: false)

      expect(portal).to have_received(:edit_mod).with("test-mod", deprecated: false)
    end

    it "edits MOD with multiple metadata fields" do
      command.call(
        mod_name: "test-mod",
        description: "Full description",
        category: "content",
        license: "default_apache2",
        tags: %w[automation optimization]
      )

      expect(portal).to have_received(:edit_mod).with(
        "test-mod",
        description: "Full description",
        category: "content",
        license: "default_apache2",
        tags: %w[automation optimization]
      )
    end

    it "edits MOD with all metadata fields" do
      command.call(
        mod_name: "test-mod",
        description: "Description",
        summary: "Summary",
        title: "Title",
        category: "tweaks",
        tags: %w[tag1 tag2],
        license: "default_gnugplv3",
        homepage: "https://homepage.example.com",
        source_url: "https://github.com/example/repo",
        faq: "FAQ content",
        deprecated: true
      )

      expect(portal).to have_received(:edit_mod).with(
        "test-mod",
        description: "Description",
        summary: "Summary",
        title: "Title",
        category: "tweaks",
        tags: %w[tag1 tag2],
        license: "default_gnugplv3",
        homepage: "https://homepage.example.com",
        source_url: "https://github.com/example/repo",
        faq: "FAQ content",
        deprecated: true
      )
    end

    context "when no metadata is provided" do
      it "raises error with message" do
        expect { command.call(mod_name: "test-mod") }.to raise_error(Factorix::Error, "No metadata options provided")
        expect(portal).not_to have_received(:edit_mod)
      end
    end

    context "when errors occur" do
      it "raises error for bad request" do
        allow(portal).to receive(:edit_mod).and_raise(
          Factorix::HTTPClientError.new("400 Bad Request")
        )

        expect {
          command.call(mod_name: "test-mod", description: "New description")
        }.to raise_error(Factorix::HTTPClientError, /Bad Request/)
      end
    end

    context "when invalid license is provided" do
      it "raises error for unknown license identifier" do
        expect {
          command.call(mod_name: "test-mod", license: "invalid_license")
        }.to raise_error(Factorix::Error, "Invalid license identifier")
        expect(portal).not_to have_received(:edit_mod)
      end

      it "raises error for MIT without default_ prefix" do
        expect {
          command.call(mod_name: "test-mod", license: "MIT")
        }.to raise_error(Factorix::Error, "Invalid license identifier")
        expect(portal).not_to have_received(:edit_mod)
      end

      it "raises error for custom license with wrong hex length" do
        expect {
          command.call(mod_name: "test-mod", license: "custom_0123456789abcdef")
        }.to raise_error(Factorix::Error, "Invalid license identifier")
        expect(portal).not_to have_received(:edit_mod)
      end

      it "raises error for custom license with uppercase hex" do
        expect {
          command.call(mod_name: "test-mod", license: "custom_0123456789ABCDEF01234567")
        }.to raise_error(Factorix::Error, "Invalid license identifier")
        expect(portal).not_to have_received(:edit_mod)
      end
    end
  end

  describe "#build_metadata" do
    it "returns empty hash when no metadata provided" do
      metadata = command.__send__(:build_metadata)
      expect(metadata).to eq({})
    end

    it "includes description when provided" do
      metadata = command.__send__(:build_metadata, description: "Desc")
      expect(metadata).to eq({description: "Desc"})
    end

    it "includes summary when provided" do
      metadata = command.__send__(:build_metadata, summary: "Sum")
      expect(metadata).to eq({summary: "Sum"})
    end

    it "includes title when provided" do
      metadata = command.__send__(:build_metadata, title: "Title")
      expect(metadata).to eq({title: "Title"})
    end

    it "includes category when provided" do
      metadata = command.__send__(:build_metadata, category: "content")
      expect(metadata).to eq({category: "content"})
    end

    it "includes tags when provided" do
      metadata = command.__send__(:build_metadata, tags: %w[tag1 tag2])
      expect(metadata).to eq({tags: %w[tag1 tag2]})
    end

    it "includes license when provided" do
      metadata = command.__send__(:build_metadata, license: "default_mit")
      expect(metadata).to eq({license: "default_mit"})
    end

    it "includes homepage when provided" do
      metadata = command.__send__(:build_metadata, homepage: "https://example.com")
      expect(metadata).to eq({homepage: "https://example.com"})
    end

    it "includes source_url when provided" do
      metadata = command.__send__(:build_metadata, source_url: "https://github.com/user/repo")
      expect(metadata).to eq({source_url: "https://github.com/user/repo"})
    end

    it "includes faq when provided" do
      metadata = command.__send__(:build_metadata, faq: "FAQ text")
      expect(metadata).to eq({faq: "FAQ text"})
    end

    it "includes deprecated when true" do
      metadata = command.__send__(:build_metadata, deprecated: true)
      expect(metadata).to eq({deprecated: true})
    end

    it "includes deprecated when false" do
      metadata = command.__send__(:build_metadata, deprecated: false)
      expect(metadata).to eq({deprecated: false})
    end

    it "excludes nil values" do
      metadata = command.__send__(
        :build_metadata,
        description: "Desc",
        summary: nil,
        title: nil,
        category: "content",
        tags: nil,
        license: "default_mit",
        homepage: nil,
        source_url: nil,
        faq: nil,
        deprecated: nil
      )

      expect(metadata).to eq({
        description: "Desc",
        category: "content",
        license: "default_mit"
      })
    end

    it "includes all metadata when provided" do
      metadata = command.__send__(
        :build_metadata,
        description: "Description",
        summary: "Summary",
        title: "Title",
        category: "tweaks",
        tags: %w[tag1 tag2],
        license: "default_gnugplv3",
        homepage: "https://homepage.com",
        source_url: "https://github.com/user/repo",
        faq: "FAQ",
        deprecated: true
      )

      expect(metadata).to eq({
        description: "Description",
        summary: "Summary",
        title: "Title",
        category: "tweaks",
        tags: %w[tag1 tag2],
        license: "default_gnugplv3",
        homepage: "https://homepage.com",
        source_url: "https://github.com/user/repo",
        faq: "FAQ",
        deprecated: true
      })
    end
  end
end
