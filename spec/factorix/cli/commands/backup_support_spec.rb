# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::BackupSupport do
  let(:test_class) do
    Class.new(Factorix::CLI::Commands::Base) do
      backup_support!

      def call(**)
        # Empty implementation for testing
      end
    end
  end

  describe "#backup_if_exists" do
    let(:temp_file) { Tempfile.new("test-file") }
    let(:file_path) { Pathname(temp_file.path) }
    let(:command) { test_class.new }

    before do
      temp_file.write("original content")
      temp_file.flush
    end

    after do
      temp_file.close
      temp_file.unlink if temp_file.path && File.exist?(temp_file.path)
      FileUtils.rm_f("#{temp_file.path}.bak")
      FileUtils.rm_f("#{temp_file.path}.custom")
    end

    context "with default backup extension" do
      before do
        command.call
      end

      it "creates backup file with .bak extension" do
        command.__send__(:backup_if_exists, file_path)

        backup_path = Pathname("#{file_path}.bak")
        expect(backup_path).to exist
        expect(backup_path.read).to eq("original content")
      end

      it "removes the original file" do
        command.__send__(:backup_if_exists, file_path)

        expect(file_path).not_to exist
      end
    end

    context "with custom backup extension" do
      before do
        command.call(backup_extension: ".custom")
      end

      it "creates backup file with custom extension" do
        command.__send__(:backup_if_exists, file_path)

        backup_path = Pathname("#{file_path}.custom")
        expect(backup_path).to exist
        expect(backup_path.read).to eq("original content")
      end
    end

    context "when file does not exist" do
      let(:non_existent_path) { Pathname("/tmp/non-existent-file-#{SecureRandom.hex(8)}") }

      before do
        command.call
      end

      it "does nothing" do
        expect { command.__send__(:backup_if_exists, non_existent_path) }.not_to raise_error
      end
    end
  end
end
