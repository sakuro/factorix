# frozen_string_literal: true

module Factorix
  class Runtime
    # Linux runtime environment
    class Linux < self
      # Return the path to the Factorio executable
      # @return [Pathname] path to the Factorio executable
      def executable
        raise NotImplementedError
      end

      # Return the path to the Factorio data directory
      # @return [Pathname] path to the Factorio data directory
      def user_dir
        raise NotImplementedError
      end

      # Return the path to the Factorio data directory
      # @return [Pathname] path to the Factorio data directory
      def data_dir
        raise NotImplementedError
      end
    end
  end
end
