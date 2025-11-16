# frozen_string_literal: true

# Shared context for mocking runtime in CLI command specs
RSpec.shared_context "with mock runtime" do
  let(:runtime) do
    instance_double(Factorix::Runtime::Base, factorix_config_path: Pathname("/tmp/factorix/config.rb"))
  end

  before do
    # Allow Application[:runtime] to return the mock, but call original for other keys
    allow(Factorix::Application).to receive(:[]).and_call_original
    allow(Factorix::Application).to receive(:[]).with(:runtime).and_return(runtime)
  end
end

# Auto-include this context in all CLI command specs based on file path
RSpec.configure do |config|
  config.include_context "with mock runtime", file_path: %r{spec/factorix/cli/commands}
end
