# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Completion::Zsh do
  describe "#call" do
    it "outputs zsh completion script" do
      expect { Factorix::CLI::Commands::Completion::Zsh.new.call }.to output(/\A#compdef factorix/).to_stdout
    end

    it "includes _factorix function" do
      expect { Factorix::CLI::Commands::Completion::Zsh.new.call }.to output(/_factorix\(\)/).to_stdout
    end

    it "includes _factorix_completion function" do
      expect { Factorix::CLI::Commands::Completion::Zsh.new.call }.to output(/_factorix_completion\(\)/).to_stdout
    end

    it "includes compdef directive" do
      expect { Factorix::CLI::Commands::Completion::Zsh.new.call }.to output(/compdef _factorix factorix/).to_stdout
    end
  end
end
