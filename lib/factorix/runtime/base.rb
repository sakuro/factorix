# frozen_string_literal: true

require "pathname"

module Factorix
  class Runtime
    # Abstract base class for platform-specific runtime environments
    #
    # This class defines the interface that all platform-specific runtime
    # implementations must provide. It provides common implementations for
    # derived paths and XDG Base Directory specification support.
    class Base
      # Get the Factorio user directory path
      #
      # This directory contains user-specific Factorio data including mods,
      # saves, configuration files, and player data.
      #
      # @return [Pathname] the Factorio user directory
      # @raise [NotImplementedError] if not implemented by the platform
      def user_dir
        raise NotImplementedError, "#{self.class}#user_dir is not implemented"
      end

      # Get the MODs directory path of Factorio
      #
      # This directory contains all installed MODs and MOD configuration files
      # such as mod-list.json and mod-settings.dat.
      #
      # @return [Pathname] the MODs directory of Factorio
      def mods_dir
        user_dir + "mods"
      end

      # Get the path of the mod-list.json file
      #
      # This file contains the list of installed MODs and their enabled/disabled states.
      #
      # @return [Pathname] the path of the mod-list.json file
      def mod_list_path
        mods_dir + "mod-list.json"
      end

      # Get the path of the mod-settings.dat file
      #
      # This file contains the MOD settings for startup, runtime-global, and runtime-per-user.
      #
      # @return [Pathname] the path of the mod-settings.dat file
      def mod_settings_path
        mods_dir + "mod-settings.dat"
      end

      # Get the path of the player-data.json file
      #
      # This file contains player-specific data including authentication credentials,
      # preferences, and game statistics.
      #
      # @return [Pathname] the path of the player-data.json file
      def player_data_path
        user_dir + "player-data.json"
      end

      # Get the XDG cache home directory
      #
      # Returns the base directory for user-specific cache data according to
      # the XDG Base Directory Specification. On platforms that don't follow
      # XDG conventions, this returns the platform-appropriate equivalent.
      #
      # @return [Pathname] the XDG cache home directory
      def xdg_cache_home_dir
        if ENV.key?("XDG_CACHE_HOME")
          Pathname(ENV.fetch("XDG_CACHE_HOME"))
        else
          default_cache_home_dir
        end
      end

      # Get the XDG config home directory
      #
      # Returns the base directory for user-specific configuration files according to
      # the XDG Base Directory Specification. On platforms that don't follow
      # XDG conventions, this returns the platform-appropriate equivalent.
      #
      # @return [Pathname] the XDG config home directory
      def xdg_config_home_dir
        if ENV.key?("XDG_CONFIG_HOME")
          Pathname(ENV.fetch("XDG_CONFIG_HOME"))
        else
          default_config_home_dir
        end
      end

      # Get the XDG data home directory
      #
      # Returns the base directory for user-specific data files according to
      # the XDG Base Directory Specification. On platforms that don't follow
      # XDG conventions, this returns the platform-appropriate equivalent.
      #
      # @return [Pathname] the XDG data home directory
      def xdg_data_home_dir
        if ENV.key?("XDG_DATA_HOME")
          Pathname(ENV.fetch("XDG_DATA_HOME"))
        else
          default_data_home_dir
        end
      end

      # Get the Factorix cache directory
      #
      # Returns the directory where Factorix stores its cache data.
      #
      # @return [Pathname] the Factorix cache directory
      def factorix_cache_dir
        xdg_cache_home_dir / "factorix"
      end

      # Get the Factorix configuration file path
      #
      # Returns the path to the Factorix configuration file.
      #
      # @return [Pathname] the Factorix configuration file path
      def factorix_config_path
        xdg_config_home_dir / "factorix" / "config.rb"
      end

      # Get the default cache home directory for this platform
      #
      # This method should be overridden by platform-specific subclasses
      # to provide appropriate defaults.
      #
      # @return [Pathname] the default cache home directory
      private def default_cache_home_dir
        Pathname(Dir.home).join(".cache")
      end

      # Get the default config home directory for this platform
      #
      # This method should be overridden by platform-specific subclasses
      # to provide appropriate defaults.
      #
      # @return [Pathname] the default config home directory
      private def default_config_home_dir
        Pathname(Dir.home).join(".config")
      end

      # Get the default data home directory for this platform
      #
      # This method should be overridden by platform-specific subclasses
      # to provide appropriate defaults.
      #
      # @return [Pathname] the default data home directory
      private def default_data_home_dir
        Pathname(Dir.home).join(".local/share")
      end
    end
  end
end
