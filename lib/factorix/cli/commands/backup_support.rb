# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      # Mixin for commands that backup files before writing
      #
      # This module provides:
      # - --backup-extension option to specify backup file extension
      # - backup_if_exists method to backup a file before overwriting
      #
      # Prepend this module to commands that modify mod-list.json or mod-settings.dat
      module BackupSupport
        # Hook called when this module is prepended to a class
        # @param base [Class] the class prepending this module
        def self.prepended(base)
          base.class_eval do
            option :backup_extension, type: :string, default: ".bak", desc: "Backup file extension"
          end
        end

        # Default backup extension
        DEFAULT_BACKUP_EXTENSION = ".bak"
        private_constant :DEFAULT_BACKUP_EXTENSION

        # Store the --backup-extension option for use in backup_if_exists
        # @param options [Hash] command options
        def call(**options)
          @backup_extension = options[:backup_extension] || DEFAULT_BACKUP_EXTENSION
          super
        end

        # Backup existing file if it exists
        #
        # @param path [Pathname] File path to backup
        # @return [void]
        private def backup_if_exists(path)
          return unless path.exist?

          backup_path = Pathname("#{path}#{@backup_extension}")
          path.rename(backup_path)
        end
      end
    end
  end
end
