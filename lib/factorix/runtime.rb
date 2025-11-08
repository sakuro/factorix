# frozen_string_literal: true

module Factorix
  # Factorio runtime environment abstraction
  #
  # This class provides a factory method to detect the current platform
  # and return the appropriate runtime environment instance.
  class Runtime
    # Error raised when running on an unsupported platform
    class UnsupportedPlatform < Error; end

    # Detect the current platform and return the appropriate runtime
    #
    # @return [Runtime::Base] the runtime environment for the current platform
    # @raise [UnsupportedPlatform] if the platform is not supported
    def self.detect
      case RUBY_PLATFORM
      when /darwin/
        MacOS.new
      when /mingw|mswin/
        Windows.new
      when /linux/
        wsl? ? WSL.new : Linux.new
      else
        raise UnsupportedPlatform, "Platform is not supported: #{RUBY_PLATFORM}"
      end
    end

    # Check if running on WSL
    #
    # @return [Boolean] true if running on WSL, false otherwise
    def self.wsl?
      File.exist?("/proc/version") && /microsoft/i.match?(File.read("/proc/version"))
    end
    private_class_method :wsl?
  end
end
