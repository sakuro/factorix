# frozen_string_literal: true

module Factorix
  class Runtime
    # Linux runtime environment
    class Linux < self
      # Return the path to the cache directory
      # @return [Pathname] path to the cache directory
      def cache_dir
        base = ENV.fetch("XDG_CACHE_HOME") do
          File.expand_path("~/.cache")
        end
        Pathname(base).join("factorix")
      end
    end
  end
end
