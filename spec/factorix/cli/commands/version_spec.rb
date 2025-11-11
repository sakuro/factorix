# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Version do
  describe "#call" do
    it "outputs the Factorix version" do
      expect {
        Factorix::CLI::Commands::Version.new.call
      }.to output("#{Factorix::VERSION}\n").to_stdout
    end
  end
end
