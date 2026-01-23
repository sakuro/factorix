# frozen_string_literal: true

# Factorix Configuration Example
#
# This file shows how to configure Factorix for different platforms
# and installation methods.
#
# Copy this file to: ~/.config/factorix/config.rb
# Or specify with: factorix --config-path /path/to/config.rb

Factorix.configure do |config|
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
  # Each cache type supports multiple backends with hierarchical configuration.
  # Common settings (backend, ttl) apply to all backends.
  # Backend-specific settings are nested under the backend name.

  # Download cache settings (for MOD files)
  # config.cache.download.backend = :file_system  # Currently only :file_system is supported
  # config.cache.download.ttl = nil  # nil = unlimited (MOD files are immutable)
  # config.cache.download.file_system.root = Pathname("~/.cache/factorix/download")
  # config.cache.download.file_system.max_file_size = nil  # nil = unlimited
  # config.cache.download.file_system.compression_threshold = nil  # nil = no compression

  # API cache settings (for API responses)
  # config.cache.api.backend = :file_system
  # config.cache.api.ttl = 3600  # 1 hour
  # config.cache.api.file_system.root = Pathname("~/.cache/factorix/api")
  # config.cache.api.file_system.max_file_size = 10 * 1024 * 1024  # 10MiB
  # config.cache.api.file_system.compression_threshold = 0  # Always compress

  # info.json cache settings (for MOD metadata from ZIP files)
  # config.cache.info_json.backend = :file_system
  # config.cache.info_json.ttl = nil  # nil = unlimited (info.json is immutable)
  # config.cache.info_json.file_system.root = Pathname("~/.cache/factorix/info_json")
  # config.cache.info_json.file_system.max_file_size = nil  # nil = unlimited
  # config.cache.info_json.file_system.compression_threshold = 0  # Always compress

end
