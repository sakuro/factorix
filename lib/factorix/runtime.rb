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

    # Raised when the game is already running and an attempt to launch the game is made
    class AlreadyRunning < StandardError; end

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

    # Launch the game
    # @raise [RuntimeError] if the game is already running
    def launch(*)
      raise AlreadyRunning, "The game is already running" if running?

      spawn([executable.to_s, "factorio"], *, out: IO::NULL)
    end

    # Check if the game is running
    #
    # Becasuse the game becomes daemonized on launch, we cannot use the process ID nor Process groups
    # to check if the game is running.  Instead, we check if the game is running by external means.
    # (e.g. polling the process list periodically)
    #
    # Note: Subclasses should implement this method
    # @return [Boolean] true if the game is running, false otherwise
    def running?
      raise NotImplementedError
    end
  end
end
