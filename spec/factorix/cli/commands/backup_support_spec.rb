# frozen_string_literal: true

require "tempfile"

RSpec.describe Factorix::CLI::Commands::BackupSupport do
  describe "#backup_if_exists" do
    let(:temp_file) { Tempfile.new("test-file") }
    let(:file_path) { Pathname(temp_file.path) }

    before do
      temp_file.write("original content")
      temp_file.flush

      # Define test command that calls backup_if_exists in call method
      test_class = Class.new(Factorix::CLI::Commands::Base) do
        argument :path, required: true, desc: "File path to backup"

        backup_support!

        def call(path:, **)
          backup_if_exists(Pathname(path))
        end
      end
      stub_const("TestBackupCommand", test_class)
    end

    after do
      temp_file.close
      temp_file.unlink if temp_file.path && File.exist?(temp_file.path)
      FileUtils.rm_f("#{temp_file.path}.bak")
      FileUtils.rm_f("#{temp_file.path}.custom")
    end

    context "with default backup extension" do
      it "creates backup file with .bak extension" do
        run_command(TestBackupCommand, [file_path.to_s])

        backup_path = Pathname("#{file_path}.bak")
        expect(backup_path).to exist
        expect(backup_path.read).to eq("original content")
      end

      it "removes the original file" do
        run_command(TestBackupCommand, [file_path.to_s])

        expect(file_path).not_to exist
      end
    end

    context "with custom backup extension" do
      it "creates backup file with custom extension" do
        run_command(TestBackupCommand, [file_path.to_s, "--backup-extension=.custom"])

        backup_path = Pathname("#{file_path}.custom")
        expect(backup_path).to exist
        expect(backup_path.read).to eq("original content")
      end
    end

    context "when file does not exist" do
      let(:non_existent_path) { Pathname("/tmp/non-existent-file-#{SecureRandom.hex(8)}") }

      it "does nothing" do
        result = run_command(TestBackupCommand, [non_existent_path.to_s], rescue_exception: true)
        expect(result.exception).to be_nil
      end
    end
  end
end
