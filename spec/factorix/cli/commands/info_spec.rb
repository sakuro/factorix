# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::Info do
  let(:runtime) { Factorix::Runtime.new }
  let(:command) { Factorix::CLI::Commands::Info.new }

  before do
    allow(Factorix::Runtime).to receive(:runtime).and_return(runtime)
    allow(runtime).to receive_messages(
      executable: Pathname("/path/to/factorio"),
      user_dir: Pathname("/path/to/user_dir"),
      data_dir: Pathname("/path/to/data_dir"),
      mods_dir: Pathname("/path/to/mods_dir"),
      script_output_dir: Pathname("/path/to/script_output_dir")
    )
  end

  describe "#call" do
    subject(:call) { command.call }

    it "outputs runtime information" do
      expect { call }.to output(<<~OUTPUT).to_stdout
        Executable: /path/to/factorio
        User directory: /path/to/user_dir
        Data directory: /path/to/data_dir
        MOD directory: /path/to/mods_dir
        Script output directory: /path/to/script_output_dir
      OUTPUT
    end
  end
end
