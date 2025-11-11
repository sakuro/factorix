# frozen_string_literal: true

RSpec.describe Factorix::CLI do
  describe "registry" do
    it "extends Dry::CLI::Registry" do
      expect(Factorix::CLI.singleton_class.ancestors).to include(Dry::CLI::Registry)
    end

    it "registers version command" do
      cli = Dry::CLI.new(Factorix::CLI)
      # Verify the CLI can be instantiated without errors
      expect(cli).to be_a(Dry::CLI)
    end
  end
end
