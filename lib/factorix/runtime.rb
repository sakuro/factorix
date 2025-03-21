# frozen_string_literal: true

require_relative "errors"
require_relative "mod_context"
require_relative "runtime/linux"
require_relative "runtime/mac_os"
require_relative "runtime/windows"
require_relative "runtime/wsl"

module Factorix
  # Factorio runtime environment
  class Runtime
    # Raised when run on unsupported platform
    class UnsupportedPlatform < Error; end

    # Raised when the game is already running and an attempt to launch the game is made
    class AlreadyRunning < Error; end

    # Return the platform the script is running on
    # @return [Runtime] the runtime environment
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

    # Return the mods directory of Factorio
    # @return [Pathname] the mods directory of Factorio
    def mods_dir
      user_dir + "mods"
    end

    # Return the script-output directory of Factorio
    # @return [Pathname] the script-output directory of Factorio
    def script_output_dir
      user_dir + "script-output"
    end

    # Return the path of the mod-list.json file
    # @return [Pathname] the path of the mod-list.json file
    def mod_list_path
      mods_dir + "mod-list.json"
    end

    # Return the path of the mod-settings.dat file
    # @return [Pathname] the path of the mod-settings.dat file
    def mod_settings_path
      mods_dir + "mod-settings.dat"
    end

    # Return the path of the player-data.json file
    # @return [Pathname] the path of the player-data.json file
    def player_data_path
      user_dir + "player-data.json"
    end

    # Launch the game
    # @return [void]
    # @raise [RuntimeError] if the game is already running
    def launch(*, async:)
      raise AlreadyRunning, "The game is already running" if running?

      if async
        spawn([executable.to_s, "factorio"], *, out: IO::NULL)
      else
        system([executable.to_s, "factorio"], *, out: IO::NULL)
      end
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

    # Evaluate the block with only the specified mods enabled
    # @param mod_names [Array<String>] the names of the mods to enable
    # @yield the block to evaluate
    # @return [void]
    def with_only_mod_enabled(*mod_names, &)
      list = Factorix::ModList.load
      context = ModContext.new(list)
      context.with_only_enabled(*mod_names, &)
    end

    # @return [Pathname] path to the executable file
    def executable
      raise NotImplementedError
    end

    # @return [Pathname] path to the user directory
    def user_dir
      raise NotImplementedError
    end

    # @return [Pathname] path to the data directory
    def data_dir
      raise NotImplementedError
    end

    # @return [Pathname] path to the cache directory
    def cache_dir
      raise NotImplementedError
    end
  end
end
