# frozen_string_literal: true

require "uri"

module Factorix
  module API
    License = Data.define(:id, :name, :title, :description, :url)

    # License object from MOD Portal API
    #
    # Represents a MOD license information.
    # Uses flyweight pattern for standard licenses.
    # Also provides valid license identifiers for edit_details API.
    #
    # @see https://wiki.factorio.com/Mod_portal_API
    # @see https://wiki.factorio.com/Mod_details_API#License
    class License
      # @!attribute [r] id
      #   @return [String] license ID
      # @!attribute [r] name
      #   @return [String] license name
      # @!attribute [r] title
      #   @return [String] license title
      # @!attribute [r] description
      #   @return [String] license description (long text)
      # @!attribute [r] url
      #   @return [URI::HTTPS] license URL

      # Predefined standard license instances
      DEFAULT_MIT = new(
        id: "default_mit",
        name: "MIT",
        title: "MIT License",
        description: "A permissive license that is short and to the point. It lets people do anything with your code with proper attribution and without warranty.",
        url: "https://raw.githubusercontent.com/spdx/license-list-data/main/text/MIT.txt"
      )
      private_constant :DEFAULT_MIT
      DEFAULT_GNUGPLV3 = new(
        id: "default_gnugplv3",
        name: "GNU GPLv3",
        title: "GNU General Public License v3.0",
        description: "The GNU GPL is the most widely used free software license and has a strong copyleft requirement.",
        url: "https://raw.githubusercontent.com/spdx/license-list-data/main/text/GPL-3.0-or-later.txt"
      )
      private_constant :DEFAULT_GNUGPLV3
      DEFAULT_GNULGPLV3 = new(
        id: "default_gnulgplv3",
        name: "GNU LGPLv3",
        title: "GNU Lesser General Public License v3.0",
        description: "Version 3 of the GNU LGPL is an additional set of permissions to the GNU GPLv3 license that requires derived works use the same license.",
        url: "https://raw.githubusercontent.com/spdx/license-list-data/main/text/LGPL-3.0-or-later.txt"
      )
      private_constant :DEFAULT_GNULGPLV3
      DEFAULT_MOZILLA2 = new(
        id: "default_mozilla2",
        name: "Mozilla Public License 2.0",
        title: "Mozilla Public License Version 2.0",
        description: "The Mozilla Public License (MPL 2.0) attempts to be a compromise between the permissive BSD license and the reciprocal GPL license.",
        url: "https://raw.githubusercontent.com/spdx/license-list-data/main/text/MPL-2.0.txt"
      )
      private_constant :DEFAULT_MOZILLA2
      DEFAULT_APACHE2 = new(
        id: "default_apache2",
        name: "Apache License 2.0",
        title: "Apache License, Version 2.0",
        description: "A permissive license that also provides an express grant of patent rights from contributors to users.",
        url: "https://raw.githubusercontent.com/spdx/license-list-data/main/text/Apache-2.0.txt"
      )
      private_constant :DEFAULT_APACHE2
      DEFAULT_UNLICENSE = new(
        id: "default_unlicense",
        name: "The Unlicense",
        title: "The Unlicense",
        description: "The Unlicense is a template to waive copyright interest in software and dedicate it to the public domain.",
        url: "https://raw.githubusercontent.com/spdx/license-list-data/main/text/Unlicense.txt"
      )
      private_constant :DEFAULT_UNLICENSE

      # Lookup table for flyweight pattern
      LICENSES = {
        "default_mit" => DEFAULT_MIT,
        "default_gnugplv3" => DEFAULT_GNUGPLV3,
        "default_gnulgplv3" => DEFAULT_GNULGPLV3,
        "default_mozilla2" => DEFAULT_MOZILLA2,
        "default_apache2" => DEFAULT_APACHE2,
        "default_unlicense" => DEFAULT_UNLICENSE
      }.freeze
      private_constant :LICENSES

      # Pattern for custom license identifiers (custom_ + 24 lowercase hex chars)
      CUSTOM_LICENSE_PATTERN = /\Acustom_[0-9a-f]{24}\z/
      private_constant :CUSTOM_LICENSE_PATTERN

      # @return [Array<String>] all license identifiers
      def self.identifiers = LICENSES.keys

      # Get License instance for the given identifier
      #
      # Returns predefined instance for known licenses (flyweight pattern).
      # Raises an error for unknown license identifiers.
      #
      # @param id [String] license identifier
      # @return [License] License instance
      # @raise [KeyError] if license identifier is unknown
      def self.for(id) = LICENSES.fetch(id.to_s)

      # Check if the given value is a valid license identifier
      #
      # @param value [String] license identifier
      # @return [Boolean] true if valid (standard or custom license)
      def self.valid_identifier?(value)
        LICENSES.key?(value) || CUSTOM_LICENSE_PATTERN.match?(value)
      end

      # @param id [String] license ID
      # @param name [String] license name
      # @param title [String] license title
      # @param description [String] license description
      # @param url [String] license URL
      # @return [License] new License instance
      def initialize(id:, name:, title:, description:, url:)
        url = URI(url)
        super
      end
    end
  end
end
