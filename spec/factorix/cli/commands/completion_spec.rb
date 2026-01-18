# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Completion do
  describe "#call" do
    context "with zsh argument" do
      it "outputs zsh completion script" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[zsh])
        expect(result.stdout).to match(/\A#compdef factorix/)
      end

      it "includes _factorix function" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[zsh])
        expect(result.stdout).to match(/_factorix\(\)/)
      end

      it "includes compdef directive" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[zsh])
        expect(result.stdout).to match(/compdef _factorix factorix/)
      end
    end

    context "with bash argument" do
      it "outputs bash completion script" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[bash])
        expect(result.stdout).to match(/\A# Bash completion for factorix/)
      end

      it "includes _factorix function" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[bash])
        expect(result.stdout).to match(/_factorix\(\)/)
      end

      it "includes complete directive" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[bash])
        expect(result.stdout).to match(/complete -F _factorix factorix/)
      end
    end

    context "with fish argument" do
      it "outputs fish completion script" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[fish])
        expect(result.stdout).to match(/\A# Fish completion for factorix/)
      end

      it "includes __factorix_installed_mods function" do
        result = run_command(Factorix::CLI::Commands::Completion, %w[fish])
        expect(result.stdout).to match(/__factorix_installed_mods/)
      end
    end

    context "with unsupported shell" do
      it "exits with error via dry-cli validation" do
        expect {
          run_command(Factorix::CLI::Commands::Completion, %w[unknown])
        }.to raise_error(SystemExit)
      end
    end

    context "with shell detection from SHELL environment variable" do
      around do |example|
        original_shell = ENV.fetch("SHELL", nil)
        example.run
        ENV["SHELL"] = original_shell
      end

      it "detects zsh" do
        ENV["SHELL"] = "/bin/zsh"
        result = run_command(Factorix::CLI::Commands::Completion)
        expect(result.stdout).to match(/\A#compdef factorix/)
      end

      it "detects bash" do
        ENV["SHELL"] = "/bin/bash"
        result = run_command(Factorix::CLI::Commands::Completion)
        expect(result.stdout).to match(/\A# Bash completion for factorix/)
      end

      it "detects fish" do
        ENV["SHELL"] = "/usr/bin/fish"
        result = run_command(Factorix::CLI::Commands::Completion)
        expect(result.stdout).to match(/\A# Fish completion for factorix/)
      end

      it "raises error for unknown shell" do
        ENV["SHELL"] = "/bin/unknown"
        expect {
          run_command(Factorix::CLI::Commands::Completion)
        }.to raise_error(Factorix::Error, /Cannot detect shell type/)
      end
    end
  end
end
