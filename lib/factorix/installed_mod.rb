# frozen_string_literal: true

require "dry/events"

module Factorix
  InstalledMOD = Data.define(:mod, :version, :form, :path, :info)

  # Represents a MOD installed in the mod directory or data directory
  #
  # InstalledMOD represents an actual MOD package found in either:
  # - The mod directory (user-installed MODs as ZIP files or directories)
  # - The data directory (base and expansion MODs bundled with the game)
  #
  # This is distinct from MOD (which is just a name identifier) and
  # MODState (which represents desired state in mod-list.json).
  #
  # @!attribute [r] mod
  #   @return [Factorix::MOD] The MOD identifier
  # @!attribute [r] version
  #   @return [Factorix::Types::MODVersion] The MOD version
  # @!attribute [r] form
  #   @return [Symbol] :zip or :directory
  # @!attribute [r] path
  #   @return [Pathname] The path to the ZIP file or directory
  # @!attribute [r] info
  #   @return [Factorix::Types::InfoJSON] The parsed info.json metadata
  class InstalledMOD
    include Comparable

    # Make the class itself enumerable over all installed MODs
    class << self
      include Enumerable
    end

    # Form constants
    ZIP_FORM = :zip
    DIRECTORY_FORM = :directory
    public_constant :ZIP_FORM, :DIRECTORY_FORM

    # Get all installed MODs
    #
    # @param handler [Progress::ScanHandler, nil] optional event handler for progress tracking
    # @return [Array<InstalledMOD>] Array of all installed MODs
    def self.all(handler: nil)
      scanner = Scanner.new
      scanner.subscribe(handler) if handler
      result = scanner.scan
      scanner.unsubscribe(handler) if handler
      result
    end

    # Enumerate over all installed MODs
    #
    # @yieldparam [InstalledMOD] mod Each installed MOD
    # @return [Enumerator, Array] Enumerator if no block given, otherwise the result of the block
    def self.each(&) = all.each(&)

    # Create InstalledMOD from a ZIP file
    #
    # @param path [Pathname] Path to the ZIP file
    # @return [InstalledMOD] New InstalledMOD instance
    # @raise [ArgumentError] if ZIP file is invalid
    def self.from_zip(path)
      info = Types::InfoJSON.from_zip(path)

      # Validate ZIP filename matches {name}_{version}.zip
      expected_filename = "#{info.name}_#{info.version}.zip"
      actual_filename = path.basename.to_s

      unless actual_filename == expected_filename
        raise ArgumentError, "Filename mismatch: expected #{expected_filename}, got #{actual_filename}"
      end

      new(mod: MOD[name: info.name], version: info.version, form: ZIP_FORM, path:, info:)
    end

    # Create InstalledMOD from a directory
    #
    # @param path [Pathname] Path to the directory
    # @return [InstalledMOD] New InstalledMOD instance
    # @raise [ArgumentError] if directory is invalid
    def self.from_directory(path)
      info_path = path + "info.json"
      raise ArgumentError, "Missing info.json" unless info_path.file?

      info = Types::InfoJSON.from_json(info_path.read)

      # Validate directory name matches {name}_{version} or {name}
      dirname = path.basename.to_s
      expected_unversioned = info.name
      expected_versioned = "#{info.name}_#{info.version}"

      unless dirname == expected_unversioned || dirname == expected_versioned
        raise ArgumentError, "Directory name mismatch: expected #{expected_unversioned} or #{expected_versioned}, got #{dirname}"
      end

      new(mod: MOD[name: info.name], version: info.version, form: DIRECTORY_FORM, path:, info:)
    end

    # Scanner for finding installed MODs
    #
    # Scans mod directory and data directory for installed MODs.
    # Gets directory paths from Runtime automatically.
    # Publishes progress events during scan.
    class Scanner
      include Import[:runtime, :logger]
      include Dry::Events::Publisher[:scanner]

      register_event("scan.started")
      register_event("scan.progress")
      register_event("scan.completed")

      # Scan directories for installed MODs
      #
      # Scans the mod directory for both ZIP and directory form MODs.
      # Also scans the data directory for base/expansion MODs.
      # Invalid packages are skipped with debug logging.
      # Publishes scan.started, scan.progress, and scan.completed events.
      #
      # @return [Array<InstalledMOD>] Array of installed MODs
      def scan
        installed_mods = []
        mod_dir = runtime.mod_dir
        data_dir = runtime.data_dir

        # Collect all paths to scan
        mod_paths = mod_dir.children
        data_paths = data_dir.children.select {|path|
          next false unless path.directory?

          mod_name = path.basename.to_s
          candidate_mod = MOD[name: mod_name]
          candidate_mod.base? || candidate_mod.expansion?
        }

        total = mod_paths.size + data_paths.size
        current = 0

        publish("scan.started", total:)

        # Scan user MOD directory
        mod_paths.each do |path|
          if path.file? && path.extname == ".zip"
            begin
              installed_mods << InstalledMOD.from_zip(path)
            rescue ArgumentError => e
              logger.debug("Skipping invalid ZIP MOD package", path: path.to_s, reason: e.message)
            rescue => e
              logger.debug("Skipping invalid ZIP MOD package", path: path.to_s, error: e.message)
            end
          elsif path.directory?
            begin
              installed_mods << InstalledMOD.from_directory(path)
            rescue ArgumentError => e
              logger.debug("Skipping invalid directory MOD package", path: path.to_s, reason: e.message)
            rescue => e
              logger.debug("Skipping invalid directory MOD package", path: path.to_s, error: e.message)
            end
          end
          current += 1
          publish("scan.progress", current:, total:)
        end

        # Scan data directory for base/expansion MODs only
        data_paths.each do |path|
          begin
            installed_mods << InstalledMOD.from_directory(path)
          rescue ArgumentError => e
            logger.debug("Skipping invalid directory MOD package", path: path.to_s, reason: e.message)
          rescue => e
            logger.debug("Skipping invalid directory MOD package", path: path.to_s, error: e.message)
          end
          current += 1
          publish("scan.progress", current:, total:)
        end

        publish("scan.completed", total: installed_mods.size)

        # Resolve duplicates and sort by version descending
        resolved = resolve_duplicates(installed_mods)
        resolved.sort_by(&:version).reverse
      end

      # Resolve duplicate MODs (same name and version)
      #
      # When multiple MODs with the same name and version exist, prefer
      # directory form over ZIP form.
      #
      # @param mods [Array<InstalledMOD>] Array of installed MODs
      # @return [Array<InstalledMOD>] Array with duplicates resolved
      private def resolve_duplicates(mods)
        # Group by MOD and version
        groups = mods.group_by {|mod| [mod.mod, mod.version] }

        # For each group, select the highest priority (uses InstalledMOD#<=>)
        groups.map do |_key, group_mods|
          group_mods.max
        end
      end
    end
    private_constant :Scanner

    # Compare with another InstalledMOD
    #
    # Comparison is by version (ascending), then by form (directory > ZIP)
    #
    # @param other [InstalledMOD] The other InstalledMOD
    # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
    def <=>(other)
      return nil unless other.is_a?(InstalledMOD)
      return nil unless mod == other.mod

      # Compare by version (ascending), then by form priority (directory > ZIP)
      (version <=> other.version).nonzero? || form_priority(form) <=> form_priority(other.form)
    end

    # Check if this is the base MOD
    #
    # @return [Boolean] true if this is the base MOD
    def base? = mod.base?

    # Check if this is an expansion MOD
    #
    # @return [Boolean] true if this is an expansion MOD
    def expansion? = mod.expansion?

    private def form_priority(form)
      case form
      when DIRECTORY_FORM then 1
      when ZIP_FORM then 0
      else -1
      end
    end
  end
end
