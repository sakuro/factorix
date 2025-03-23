# frozen_string_literal: true

module Factorix
  class CLI
    class Error < StandardError; end

    # Raised when trying to download a mod to a path that already exists
    class FileExistsError < Error
      def initialize(path)
        super("File already exists: #{path}")
      end
    end

    # Raised when downloaded file's SHA1 hash does not match the expected value
    class SHA1MismatchError < Error
      def initialize(path, expected:, actual:)
        super("SHA1 hash mismatch for #{path}: expected #{expected}, got #{actual}")
      end
    end
  end
end
