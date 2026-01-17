# frozen_string_literal: true

RSpec.describe "Factorix::Application" do
  describe "deprecation" do
    it "returns Container" do
      result = nil
      capture_stderr { result = Factorix::Application }
      expect(result).to eq(Factorix::Container)
    end

    it "outputs deprecation warning" do
      warning = capture_stderr { Factorix::Application }
      expect(warning).to match(/\[factorix\] Factorix::Application is deprecated, use Factorix::Container instead/)
    end
  end
end
