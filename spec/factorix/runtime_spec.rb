# frozen_string_literal: true

RSpec.describe Factorix::Runtime do
  describe ".detect" do
    let(:runtime) { Factorix::Runtime.detect }

    context "when running on macOS" do
      before do
        stub_const("RUBY_PLATFORM", "x86_64-darwin22")
      end

      it "returns MacOS runtime" do
        expect(runtime).to be_a(Factorix::Runtime::MacOS)
      end
    end

    context "when running on Windows (mingw)" do
      before do
        stub_const("RUBY_PLATFORM", "x64-mingw32")
      end

      it "returns Windows runtime" do
        expect(runtime).to be_a(Factorix::Runtime::Windows)
      end
    end

    context "when running on Windows (mswin)" do
      before do
        stub_const("RUBY_PLATFORM", "x64-mswin64")
      end

      it "returns Windows runtime" do
        expect(runtime).to be_a(Factorix::Runtime::Windows)
      end
    end

    context "when running on Linux (not WSL)" do
      before do
        stub_const("RUBY_PLATFORM", "x86_64-linux")
        allow(File).to receive(:exist?).with("/proc/version").and_return(true)
        allow(File).to receive(:read).with("/proc/version").and_return("Linux version 5.15.0")
      end

      it "returns Linux runtime" do
        expect(runtime).to be_a(Factorix::Runtime::Linux)
      end
    end

    context "when running on WSL" do
      before do
        stub_const("RUBY_PLATFORM", "x86_64-linux")
        allow(File).to receive(:exist?).with("/proc/version").and_return(true)
        allow(File).to receive(:read).with("/proc/version").and_return("Linux version 5.15.0-microsoft-standard")
      end

      it "returns WSL runtime" do
        expect(runtime).to be_a(Factorix::Runtime::WSL)
      end
    end

    context "when running on unsupported platform" do
      before do
        stub_const("RUBY_PLATFORM", "aarch64-freebsd")
      end

      it "raises UnsupportedPlatformError" do
        expect { runtime }.to raise_error(
          Factorix::UnsupportedPlatformError,
          "Platform is not supported: aarch64-freebsd"
        )
      end
    end
  end
end
