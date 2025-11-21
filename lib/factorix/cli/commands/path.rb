# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      # Display Factorio and Factorix paths
      #
      # This command outputs paths managed by the runtime environment.
      # Path types are specified as arguments with underscores (e.g., mods_dir, user_dir).
      # Input values with hyphens are automatically normalized to underscores.
      #
      # @example
      #   $ factorix path mods_dir user_dir
      #   {"mods_dir":"/path/to/mods","user_dir":"/path/to/user"}
      class Path < Base
        # Mapping from normalized path types (with underscores) to runtime method names
        PATH_TYPES = {
          "executable_path" => :executable_path,
          "user_dir" => :user_dir,
          "mod_dir" => :mod_dir,
          "save_dir" => :save_dir,
          "script_output_dir" => :script_output_dir,
          "mod_list_path" => :mod_list_path,
          "mod_settings_path" => :mod_settings_path,
          "player_data_path" => :player_data_path,
          "lock_path" => :lock_path,
          "current_log_path" => :current_log_path,
          "previous_log_path" => :previous_log_path,
          "factorix_cache_dir" => :factorix_cache_dir,
          "factorix_config_path" => :factorix_config_path,
          "factorix_log_path" => :factorix_log_path
        }.freeze
        private_constant :PATH_TYPES

        # @!parse
        #   # @return [Runtime::Base]
        #   attr_reader :runtime
        #   # @return [Dry::Logger::Dispatcher]
        #   attr_reader :logger
        include Import[:runtime, :logger]

        desc "Display Factorio and Factorix paths"

        argument :path_types, type: :array, desc: "Path types to display"

        # Execute the path command
        #
        # @param path_types [Array<String>] path types to display (defaults to all if empty)
        # @return [void]
        def call(path_types: [], **)
          # If no path types specified, show all paths
          path_types = PATH_TYPES.keys if path_types.empty?

          logger.debug("Displaying paths", path_types:)

          result = {}
          unknown_types = []

          path_types.each do |path_type|
            # Normalize: convert hyphens to underscores
            normalized = path_type.tr("-", "_")

            unless PATH_TYPES.key?(normalized)
              unknown_types << normalized
              next
            end

            method_name = PATH_TYPES[normalized]
            result[normalized] = runtime.public_send(method_name).to_s
          end

          # If there were unknown path types, show an error with available options
          unless unknown_types.empty?
            unknown_list = unknown_types.map {|t| "- #{t}" }.join("\n")
            available_keys = PATH_TYPES.keys.sort
            available_list = available_keys.map {|t| "- #{t}" }.join("\n")
            error_message = <<~ERROR
              Unknown path types:
              #{unknown_list}

              Available path types:
              #{available_list}
            ERROR
            logger.debug("Unknown path types", unknown_types:, available_types: available_keys)
            raise ArgumentError, error_message.chomp
          end

          puts JSON.pretty_generate(result)
        end
      end
    end
  end
end
