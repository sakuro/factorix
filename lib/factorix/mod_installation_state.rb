# frozen_string_literal: true

module Factorix
  # Represents the current state of MOD installation
  #
  # This class provides lazy-loaded access to:
  # - mod_list: The mod-list.json configuration
  # - installed_mods: Array of installed MODs from filesystem scan
  # - graph: Dependency graph built from installed MODs and mod-list
  #
  # Each property is evaluated only when first accessed and cached for subsequent calls.
  #
  # @example
  #   state = MODInstallationState.new(mod_list_path: runtime.mod_list_path)
  #   state.graph          # Triggers loading of mod_list, installed_mods, then graph
  #   state.mod_list       # Returns cached mod_list
  #   state.installed_mods # Returns cached installed_mods
  class MODInstallationState
    # @param mod_list_path [Pathname] path to mod-list.json
    def initialize(mod_list_path:)
      @mod_list_path = mod_list_path
    end

    # @return [MODList] loaded mod-list.json
    def mod_list = @mod_list ||= MODList.load(@mod_list_path)

    # @return [Array<InstalledMOD>] all installed MODs
    def installed_mods
      @installed_mods ||= begin
        presenter = Progress::Presenter.new(title: "\u{1F50D}\u{FE0E} Scanning MOD(s)", output: $stderr)
        handler = Progress::ScanHandler.new(presenter)
        InstalledMOD.all(handler:)
      end
    end

    # @return [Dependency::Graph] dependency graph
    def graph = @graph ||= Dependency::Graph::Builder.build(installed_mods:, mod_list:)
  end
end
