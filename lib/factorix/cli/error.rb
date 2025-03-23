# frozen_string_literal: true

module Factorix
  class CLI
    class Error < StandardError; end

    # Raised when trying to download a mod to a path that already exists
    class FileExistsError < Error; end

    # Raised when downloaded file's SHA1 hash does not match the expected value
    class SHA1MismatchError < Error; end

    # Raised when output directory does not exist
    class DirectoryNotFoundError < Error; end

    # Raised when output directory is not writable
    class DirectoryNotWritableError < Error; end
  end
end
