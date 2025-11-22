# frozen_string_literal: true

RSpec.shared_context "with suppressed output" do
  before do
    allow(command).to receive(:say)
    allow(command).to receive(:puts)
    allow(command).to receive(:print)
  end
end
