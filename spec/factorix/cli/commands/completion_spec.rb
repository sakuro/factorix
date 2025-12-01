# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Completion do
  let(:command) { Factorix::CLI::Commands::Completion.new }

  include_context "with suppressed output"

  describe "#call" do
    context "with zsh argument" do
      it "outputs zsh completion script" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "zsh") }.to output(/\A#compdef factorix/).to_stdout
      end

      it "includes _factorix function" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "zsh") }.to output(/_factorix\(\)/).to_stdout
      end

      it "includes compdef directive" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "zsh") }.to output(/compdef _factorix factorix/).to_stdout
      end
    end

    context "with bash argument" do
      it "outputs bash completion script" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "bash") }.to output(/\A# Bash completion for factorix/).to_stdout
      end

      it "includes _factorix function" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "bash") }.to output(/_factorix\(\)/).to_stdout
      end

      it "includes complete directive" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "bash") }.to output(/complete -F _factorix factorix/).to_stdout
      end
    end

    context "with fish argument" do
      it "outputs fish completion script" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "fish") }.to output(/\A# Fish completion for factorix/).to_stdout
      end

      it "includes __factorix_installed_mods function" do
        expect { Factorix::CLI::Commands::Completion.new.call(shell: "fish") }.to output(/__factorix_installed_mods/).to_stdout
      end
    end

    context "with unsupported shell" do
      it "raises an error" do
        expect { command.call(shell: "unknown") }.to raise_error(Factorix::Error, /Unsupported shell/)
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
        expect { Factorix::CLI::Commands::Completion.new.call }.to output(/\A#compdef factorix/).to_stdout
      end

      it "detects bash" do
        ENV["SHELL"] = "/bin/bash"
        expect { Factorix::CLI::Commands::Completion.new.call }.to output(/\A# Bash completion for factorix/).to_stdout
      end

      it "detects fish" do
        ENV["SHELL"] = "/usr/bin/fish"
        expect { Factorix::CLI::Commands::Completion.new.call }.to output(/\A# Fish completion for factorix/).to_stdout
      end

      it "raises error for unknown shell" do
        ENV["SHELL"] = "/bin/unknown"
        expect { command.call }.to raise_error(Factorix::Error, /Cannot detect shell type/)
      end
    end
  end
end
