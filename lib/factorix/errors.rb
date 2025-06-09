# frozen_string_literal: true

module Factorix
  # Base error class for Factorix
  class Error < StandardError; end

  # CLI related exceptions
  class CLIError < Error; end
  class FileExistsError < CLIError; end
  class SHA1MismatchError < CLIError; end
  class DirectoryNotFoundError < CLIError; end
  class DirectoryNotWritableError < CLIError; end
  class ExtraDataError < CLIError; end

  # ModPortal related exceptions
  class ModPortalError < Error; end
  class ModPortalRequestError < ModPortalError; end
  class ModPortalResponseError < ModPortalError; end
  class ModPortalValidationError < ModPortalError; end

  # MOD related exceptions
  class ModError < Error; end
  class ModNotFoundError < ModError; end
  class InvalidModSectionError < ModError; end
  class ModSectionNotFoundError < ModError; end
  class UnknownPropertyType < ModError; end
  class DownloadError < ModError; end
end
