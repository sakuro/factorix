# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Version do
  describe "#call" do
    it "outputs the Factorix version" do
      result = run_command(Factorix::CLI::Commands::Version)
      expect(result.stdout).to eq("#{Factorix::VERSION}\n")
    end
  end
end
