# frozen_string_literal: true

module Factorix
  # Represents a MOD installed in the mod directory
  #
  # InstalledMOD represents an actual MOD package found in the mod directory,
  # either as a ZIP file or as a directory. This is distinct from MOD (which is
  # just a name identifier) and MODState (which represents desired state in mod-list.json).
  #
  # Base and expansion MODs are not included in scans, as they are bundled with
  # the game itself and not stored in the mod directory.
  class InstalledMOD
    include Comparable

    # Form constants
    ZIP_FORM = :zip
    DIRECTORY_FORM = :directory
    public_constant :ZIP_FORM, :DIRECTORY_FORM

    # Scan the mod directory for installed MODs
    #
    # Scans the given mod directory for both ZIP and directory form MODs.
    # Invalid packages are skipped with debug logging.
    #
    # @param mod_dir [Pathname] The mod directory to scan
    # @return [Array<InstalledMOD>] Array of installed MODs
    def self.scan(mod_dir)
      logger = Factorix::Application[:logger]
      installed_mods = []

      mod_dir.children.each do |path|
        if path.file? && path.extname == ".zip"
          mod = scan_zip(path, logger)
          installed_mods << mod if mod
        elsif path.directory?
          mod = scan_directory(path, logger)
          installed_mods << mod if mod
        end
      end

      # Resolve duplicates and sort by version descending
      resolved = resolve_duplicates(installed_mods)
      resolved.sort_by {|mod| [-mod.version.major, -mod.version.minor, -mod.version.patch] }
    end

    # Find all installed MODs with the given name
    #
    # @param mod_dir [Pathname] The mod directory to scan
    # @param name [String] The MOD name to search for
    # @return [Array<InstalledMOD>] Array of installed MODs with the given name, sorted by version (descending)
    def self.find_by_name(mod_dir, name)
      scan(mod_dir).select {|mod| mod.mod.name == name }
    end

    # Find an installed MOD with the given name and optional version
    #
    # If version is nil, returns the latest version.
    # If version is specified, returns the MOD with that exact version.
    #
    # @param mod_dir [Pathname] The mod directory to scan
    # @param name [String] The MOD name to search for
    # @param version [Factorix::Types::MODVersion, nil] The version to search for (nil for latest)
    # @return [InstalledMOD, nil] The found MOD or nil if not found
    def self.find(mod_dir, name, version=nil)
      mods = find_by_name(mod_dir, name)
      return nil if mods.empty?

      if version
        mods.find {|mod| mod.version == version }
      else
        mods.first # Already sorted by version descending
      end
    end

    # Scan a ZIP file and create InstalledMOD if valid
    #
    # @param path [Pathname] Path to the ZIP file
    # @param logger [Dry::Logger::Dispatcher] Logger instance
    # @return [InstalledMOD, nil] InstalledMOD instance or nil if invalid
    def self.scan_zip(path, logger)
      # Read info.json from ZIP
      info = Factorix::Types::InfoJSON.from_zip(path)

      # Validate ZIP filename matches {name}_{version}.zip
      expected_filename = "#{info.name}_#{info.version}.zip"
      actual_filename = path.basename.to_s

      unless actual_filename == expected_filename
        logger.debug(
          "Skipping invalid ZIP MOD package",
          path: path.to_s,
          reason: "Filename mismatch",
          expected: expected_filename,
          actual: actual_filename
        )
        return nil
      end

      # Create InstalledMOD instance
      new(
        mod: Factorix::MOD[name: info.name],
        version: info.version,
        form: ZIP_FORM,
        path:,
        info:
      )
    rescue => e
      logger.debug(
        "Skipping invalid ZIP MOD package",
        path: path.to_s,
        reason: "Error reading or parsing",
        error: e.message
      )
      nil
    end
    private_class_method :scan_zip

    # Scan a directory and create InstalledMOD if valid
    #
    # @param path [Pathname] Path to the directory
    # @param logger [Dry::Logger::Dispatcher] Logger instance
    # @return [InstalledMOD, nil] InstalledMOD instance or nil if invalid
    def self.scan_directory(path, logger)
      # Read info.json from directory
      info_path = path + "info.json"
      unless info_path.file?
        logger.debug(
          "Skipping invalid directory MOD package",
          path: path.to_s,
          reason: "Missing info.json"
        )
        return nil
      end

      info = Factorix::Types::InfoJSON.from_json(info_path.read)

      # Validate directory name matches {name}_{version} or {name}
      dirname = path.basename.to_s
      expected_unversioned = info.name
      expected_versioned = "#{info.name}_#{info.version}"

      unless dirname == expected_unversioned || dirname == expected_versioned
        logger.debug(
          "Skipping invalid directory MOD package",
          path: path.to_s,
          reason: "Directory name mismatch",
          expected: "#{expected_unversioned} or #{expected_versioned}",
          actual: dirname
        )
        return nil
      end

      # Create InstalledMOD instance
      new(
        mod: Factorix::MOD[name: info.name],
        version: info.version,
        form: DIRECTORY_FORM,
        path:,
        info:
      )
    rescue => e
      logger.debug(
        "Skipping invalid directory MOD package",
        path: path.to_s,
        reason: "Error reading or parsing",
        error: e.message
      )
      nil
    end
    private_class_method :scan_directory

    # Resolve duplicate MODs (same name and version)
    #
    # When multiple MODs with the same name and version exist, prefer
    # directory form over ZIP form.
    #
    # @param mods [Array<InstalledMOD>] Array of installed MODs
    # @return [Array<InstalledMOD>] Array with duplicates resolved
    def self.resolve_duplicates(mods)
      # Group by name and version
      groups = mods.group_by {|mod| [mod.mod.name, mod.version] }

      # For each group, select the highest priority form
      groups.map do |_key, group_mods|
        # Sort by form priority (directory > zip)
        group_mods.max_by {|mod| form_priority_class(mod.form) }
      end
    end
    private_class_method :resolve_duplicates

    # Get priority for form comparison (class method version)
    #
    # @param form [Symbol] The form
    # @return [Integer] Priority value
    def self.form_priority_class(form)
      case form
      when DIRECTORY_FORM then 1
      when ZIP_FORM then 0
      else -1
      end
    end
    private_class_method :form_priority_class

    # Create a new InstalledMOD instance
    #
    # @param mod [Factorix::MOD] The MOD identifier
    # @param version [Factorix::Types::MODVersion] The MOD version
    # @param form [Symbol] The form (:zip or :directory)
    # @param path [Pathname] The path to the ZIP file or directory
    # @param info [Factorix::Types::InfoJSON] The parsed info.json metadata
    # @return [void]
    def initialize(mod:, version:, form:, path:, info:)
      @mod = mod
      @version = version
      @form = form
      @path = path
      @info = info
    end

    # Get the MOD identifier
    #
    # @return [Factorix::MOD] The MOD identifier
    attr_reader :mod

    # Get the MOD version
    #
    # @return [Factorix::Types::MODVersion] The MOD version
    attr_reader :version

    # Get the form (ZIP or directory)
    #
    # @return [Symbol] :zip or :directory
    attr_reader :form

    # Get the path to the MOD package
    #
    # @return [Pathname] The path
    attr_reader :path

    # Get the parsed info.json metadata
    #
    # @return [Factorix::Types::InfoJSON] The metadata
    attr_reader :info

    # Compare with another InstalledMOD
    #
    # Comparison is by version (ascending), then by form (directory > ZIP)
    #
    # @param other [InstalledMOD] The other InstalledMOD
    # @return [Integer, nil] -1, 0, 1 for less than, equal to, greater than; nil if not comparable
    def <=>(other)
      return nil unless other.is_a?(InstalledMOD)
      return nil unless mod == other.mod

      # Compare version (ascending)
      version_cmp = version <=> other.version
      return version_cmp if version_cmp.nonzero?

      # If versions are equal, prefer directory over ZIP
      form_priority(form) <=> form_priority(other.form)
    end

    private def form_priority(form)
      case form
      when DIRECTORY_FORM then 1
      when ZIP_FORM then 0
      else -1
      end
    end
  end
end
