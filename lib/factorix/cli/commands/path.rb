# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      # Display Factorio and Factorix paths
      #
      # This command outputs all paths managed by the runtime environment.
      #
      # @example
      #   $ factorix path
      #   {"executable_path":"/path/to/factorio","user_dir":"/path/to/user",...}
      class Path < Base
        # Mapping from path type keys to runtime method names
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

        # Execute the path command
        #
        # @return [void]
        def call(**)
          logger.debug("Displaying all paths")

          result = PATH_TYPES.transform_values {|method_name| runtime.public_send(method_name).to_s }

          puts JSON.pretty_generate(result)
        end
      end
    end
  end
end
