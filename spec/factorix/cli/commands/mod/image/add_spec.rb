# frozen_string_literal: true

RSpec.describe Factorix::CLI::Commands::MOD::Image::Add do
  include_context "with suppressed output"

  let(:portal) { instance_double(Factorix::Portal) }
  let(:command) { Factorix::CLI::Commands::MOD::Image::Add.new(portal:) }
  let(:tmpdir) { Dir.mktmpdir }

  before do
    allow(Factorix::Application).to receive(:[]).and_call_original
    allow(Factorix::Application).to receive(:[]).with(:portal).and_return(portal)
  end

  after do
    FileUtils.rm_rf(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  describe "#call" do
    it "adds image when file exists" do
      image_file = File.join(tmpdir, "test.png")
      FileUtils.touch(image_file)

      image = Factorix::API::Image[
        id: "abc123",
        url: "https://example.com/image.png",
        thumbnail: "https://example.com/thumb.png"
      ]

      allow(portal).to receive(:add_mod_image).and_return(image)

      command.call(mod_name: "test-mod", image_file:)

      expect(portal).to have_received(:add_mod_image).with("test-mod", Pathname(image_file))
    end

    it "raises error when file does not exist" do
      image_file = File.join(tmpdir, "nonexistent.png")

      expect {
        command.call(mod_name: "test-mod", image_file:)
      }.to raise_error(Factorix::InvalidArgumentError, /Image file not found/)
    end

    it "raises HTTPClientError when upload fails" do
      image_file = File.join(tmpdir, "test.png")
      FileUtils.touch(image_file)

      allow(portal).to receive(:add_mod_image).and_raise(Factorix::HTTPClientError.new("403 Forbidden"))

      expect {
        command.call(mod_name: "test-mod", image_file:)
      }.to raise_error(Factorix::HTTPClientError, /403 Forbidden/)
    end
  end
end
