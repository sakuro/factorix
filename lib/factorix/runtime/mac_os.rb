# frozen_string_literal: true

require "pathname"

module Factorix
  class Runtime
    # MacOS runtime environment
    class MacOS < self
      # Return the path to the Factorio executable
      # @return [Pathname] path to the Factorio executable
      def executable
        home_dir + "Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio"
      end

      # Return the path to the user's Factorio directory
      # @return [Pathname] path to the user's Factorio directory
      def user_dir
        home_dir + "Library/Application Support/Factorio"
      end

      # Return the path to the Factorio data directory
      # @return [Pathname] path to the Factorio data directory
      def data_dir
        home_dir + "Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data"
      end

      private def home_dir = Pathname(Dir.home)
    end
  end
end
