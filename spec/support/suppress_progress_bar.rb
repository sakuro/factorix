# frozen_string_literal: true

RSpec.shared_context "with suppressed progress bar" do
  before do
    presenter = instance_double(Factorix::Progress::Presenter)
    allow(presenter).to receive(:start)
    allow(presenter).to receive(:update)
    allow(presenter).to receive(:finish)
    allow(presenter).to receive(:increase_total)
    allow(Factorix::Progress::Presenter).to receive(:new).and_return(presenter)

    multi_presenter = instance_double(Factorix::Progress::MultiPresenter)
    allow(multi_presenter).to receive(:register).and_return(presenter)
    allow(Factorix::Progress::MultiPresenter).to receive(:new).and_return(multi_presenter)
  end
end
