# frozen_string_literal: true

# Factorix Configuration Example
#
# This file shows how to configure Factorix for different platforms
# and installation methods.
#
# Copy this file to: ~/.config/factorix/config.rb
# Or specify with: factorix --config-path /path/to/config.rb

Factorix::Application.configure do |config|
  # ============================================================================
  # Runtime Configuration
  # ============================================================================
  # Configure Factorio installation paths when auto-detection is not available
  # or when you want to override the detected paths.

  # --------------------------------------------------------------------------
  # Linux Examples
  # --------------------------------------------------------------------------

  # Standalone installation (manual download)
  # config.runtime.executable_path = "/opt/factorio/bin/x64/factorio"
  # config.runtime.user_dir = "#{Dir.home}/.factorio"
  # config.runtime.data_dir = "/opt/factorio/data"

  # Steam installation (default, usually no configuration needed)
  # config.runtime.executable_path = "#{Dir.home}/.steam/steam/steamapps/common/Factorio/bin/x64/factorio"
  # config.runtime.user_dir = "#{Dir.home}/.factorio"
  # config.runtime.data_dir = "#{Dir.home}/.steam/steam/steamapps/common/Factorio/data"

  # Flatpak installation
  # config.runtime.executable_path = "/var/lib/flatpak/app/com.valvesoftware.Steam/current/active/files/extra/steam/steamapps/common/Factorio/bin/x64/factorio"
  # config.runtime.user_dir = "#{Dir.home}/.var/app/com.valvesoftware.Steam/.factorio"
  # config.runtime.data_dir = "/var/lib/flatpak/app/com.valvesoftware.Steam/current/active/files/extra/steam/steamapps/common/Factorio/data"

  # --------------------------------------------------------------------------
  # macOS Examples (non-Steam)
  # --------------------------------------------------------------------------

  # Manual installation in Applications
  # config.runtime.executable_path = "/Applications/Factorio.app/Contents/MacOS/factorio"
  # config.runtime.user_dir = "#{Dir.home}/Library/Application Support/factorio"
  # config.runtime.data_dir = "/Applications/Factorio.app/Contents/data"

  # --------------------------------------------------------------------------
  # Windows Examples (non-Steam)
  # --------------------------------------------------------------------------

  # Portable installation
  # config.runtime.executable_path = "C:/Games/Factorio/bin/x64/factorio.exe"
  # config.runtime.user_dir = "C:/Games/Factorio"
  # config.runtime.data_dir = "C:/Games/Factorio/data"

  # Standard installation
  # config.runtime.executable_path = "C:/Program Files/Factorio/bin/x64/factorio.exe"
  # config.runtime.user_dir = "#{ENV['APPDATA']}/Factorio"
  # config.runtime.data_dir = "C:/Program Files/Factorio/data"

  # ============================================================================
  # Logging Configuration
  # ============================================================================

  # Set default log level (debug, info, warn, error, fatal)
  # config.log_level = :info

  # ============================================================================
  # HTTP Configuration
  # ============================================================================

  # HTTP timeout settings (in seconds)
  # config.http.connect_timeout = 5
  # config.http.read_timeout = 30
  # config.http.write_timeout = 30

  # ============================================================================
  # Cache Configuration
  # ============================================================================

  # Download cache settings (for MOD files)
  # config.cache.download.ttl = nil  # nil = unlimited (MOD files are immutable)
  # config.cache.download.max_file_size = nil  # nil = unlimited

  # API cache settings (for API responses)
  # config.cache.api.ttl = 3600  # 1 hour
  # config.cache.api.max_file_size = 10 * 1024 * 1024  # 10MiB

end
