# frozen_string_literal: true

module Factorix
  module Cache
    Entry = Data.define(:size, :age, :expired)

    # Represents a cache entry for enumeration operations.
    #
    # Used by {Base#each} to yield entry metadata alongside keys.
    # Note: The key is NOT included in Entry; it is yielded separately.
    #
    # @!attribute [r] size
    #   @return [Integer] entry size in bytes
    # @!attribute [r] age
    #   @return [Float] age in seconds since creation/modification
    # @!attribute [r] expired
    #   @return [Boolean] whether entry has exceeded TTL
    class Entry
      # All functionality provided by Data.define
    end
  end
end
