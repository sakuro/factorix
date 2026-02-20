# frozen_string_literal: true

RSpec.describe Factorix::Changelog do
  let(:fixtures_dir) { Pathname(__dir__).parent / "fixtures" / "changelog" }

  describe ".load" do
    it "parses a basic changelog with multiple versions and categories" do
      changelog = Factorix::Changelog.load(fixtures_dir / "basic.txt")
      text = changelog.to_s

      expect(text).to include("Version: 1.1.0")
      expect(text).to include("Version: 1.0.0")
      expect(text).to include("    - Added new feature A")
      expect(text).to include("    - Fixed crash on startup")
    end

    it "parses a changelog with Date lines" do
      changelog = Factorix::Changelog.load(fixtures_dir / "with_date.txt")
      text = changelog.to_s

      expect(text).to include("Date: 2025-01-15")
      expect(text).to include("Date: 2024-06-01")
    end

    it "parses continuation lines as part of the preceding entry" do
      changelog = Factorix::Changelog.load(fixtures_dir / "multiline_entry.txt")
      text = changelog.to_s

      expect(text).to include("    - Added a complex feature that spans")
      expect(text).to include("      multiple lines of description")
    end

    it "parses an Unreleased section" do
      changelog = Factorix::Changelog.load(fixtures_dir / "with_unreleased.txt")
      text = changelog.to_s

      expect(text).to include("Version: Unreleased")
      expect(text).to include("    - Added new experimental feature")
    end

    it "returns an empty changelog when the file does not exist" do
      changelog = Factorix::Changelog.load(Pathname("/nonexistent/changelog.txt"))
      expect(changelog.to_s).to eq("\n")
    end
  end

  describe "#add_entry" do
    it "adds an entry to an existing version and category" do
      changelog = Factorix::Changelog.load(fixtures_dir / "basic.txt")
      version = Factorix::MODVersion.from_string("1.1.0")

      changelog.add_entry(version, "Features", "Added feature C")
      text = changelog.to_s

      expect(text).to include("    - Added feature C")
    end

    it "creates a new category on an existing version" do
      changelog = Factorix::Changelog.load(fixtures_dir / "basic.txt")
      version = Factorix::MODVersion.from_string("1.1.0")

      changelog.add_entry(version, "Optimizations", "Improved performance")
      text = changelog.to_s

      expect(text).to include("  Optimizations:")
      expect(text).to include("    - Improved performance")
    end

    it "creates a new section for a new version at the beginning" do
      changelog = Factorix::Changelog.load(fixtures_dir / "basic.txt")
      version = Factorix::MODVersion.from_string("2.0.0")

      changelog.add_entry(version, "Features", "New major feature")
      text = changelog.to_s

      # New version should appear before existing versions
      pos_new = text.index("Version: 2.0.0")
      pos_old = text.index("Version: 1.1.0")
      expect(pos_new).to be < pos_old
    end

    it "adds an entry to an Unreleased section" do
      changelog = Factorix::Changelog.load(fixtures_dir / "basic.txt")

      changelog.add_entry(Factorix::Changelog::UNRELEASED, "Features", "New unreleased feature")
      text = changelog.to_s

      expect(text).to include("Version: Unreleased")
      expect(text).to include("    - New unreleased feature")
    end

    it "raises InvalidArgumentError for duplicate entries" do
      changelog = Factorix::Changelog.load(fixtures_dir / "basic.txt")
      version = Factorix::MODVersion.from_string("1.1.0")

      expect {
        changelog.add_entry(version, "Features", "Added new feature A")
      }.to raise_error(Factorix::InvalidArgumentError, /duplicate entry/)
    end
  end

  describe "round-trip" do
    it "preserves content through load and save" do
      original = Factorix::Changelog.load(fixtures_dir / "basic.txt")
      original_text = original.to_s

      reparsed = Factorix::Changelog.parse(original_text)
      reparsed_text = reparsed.to_s

      expect(reparsed_text).to eq(original_text)
    end

    it "preserves Date lines through round-trip" do
      original = Factorix::Changelog.load(fixtures_dir / "with_date.txt")
      original_text = original.to_s

      reparsed = Factorix::Changelog.parse(original_text)
      expect(reparsed.to_s).to eq(original_text)
    end

    it "preserves Unreleased section through round-trip" do
      original = Factorix::Changelog.load(fixtures_dir / "with_unreleased.txt")
      original_text = original.to_s

      reparsed = Factorix::Changelog.parse(original_text)
      expect(reparsed.to_s).to eq(original_text)
    end

    it "preserves multiline entries through round-trip" do
      original = Factorix::Changelog.load(fixtures_dir / "multiline_entry.txt")
      original_text = original.to_s

      reparsed = Factorix::Changelog.parse(original_text)
      expect(reparsed.to_s).to eq(original_text)
    end
  end
end
