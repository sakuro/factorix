# frozen_string_literal: true

require_relative "runtime/linux"
require_relative "runtime/mac_os"
require_relative "runtime/windows"
require_relative "runtime/wsl"

module Factorix
  # Factorio runtime environment
  class Runtime
    # Raised when run on unsupported platform
    class UnsupportedPlatform < StandardError; end

    # Returns the platform the script is running on
    # @raise [UnsupportedPlatform] if the platform is not supported
    def self.runtime
      case RUBY_PLATFORM
      when /darwin/
        MacOS.new
      when /mingw|mswin/
        Windows.new
      when /linux/
        /microsoft/i.match?(File.read("/proc/version")) ? WSL.new : Linux.new
      else
        raise UnsupportedPlatform, "Platform is not supported: #{RUBY_PLATFORM}"
      end
    end

    # Returns the mods directory of Factorio
    # @return [Pathname] the mods directory of Factorio
    def mods_dir
      user_dir + "mods"
    end

    # Returns the script-output directory of Factorio
    # @return [Pathname] the script-output directory of Factorio
    def script_output_dir
      user_dir + "script-output"
    end

    # Returns the path of the mod-list.json file
    # @return [Pathname] the path of the mod-list.json file
    def mod_list_path
      mods_dir + "mod-list.json"
    end
  end
end
