# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Edit MOD metadata on Factorio MOD Portal
        class Edit < Base
          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          include Import[:portal]

          desc "Edit MOD metadata on Factorio MOD Portal"

          example [
            "some-mod --title \"New Title\"       # Update MOD title",
            "some-mod --category automation       # Update category",
            "some-mod --deprecated                # Mark as deprecated"
          ]

          argument :mod_name, type: :string, required: true, desc: "MOD name"
          option :description, type: :string, desc: "Markdown description"
          option :summary, type: :string, desc: "Brief description"
          option :title, type: :string, desc: "MOD title"
          option :category, type: :string, desc: "MOD category"
          option :tags, type: :array, desc: "Array of tags"
          option :license, type: :string, desc: "License identifier"
          option :homepage, type: :string, desc: "Homepage URL"
          option :source_url, type: :string, desc: "Repository URL"
          option :faq, type: :string, desc: "FAQ text"
          option :deprecated, type: :boolean, desc: "Deprecation flag"

          # Execute the edit command
          #
          # @param mod_name [String] the mod name
          # @param description [String, nil] optional description
          # @param summary [String, nil] optional summary
          # @param title [String, nil] optional title
          # @param category [String, nil] optional category
          # @param tags [Array<String>, nil] optional tags
          # @param license [String, nil] optional license
          # @param homepage [String, nil] optional homepage
          # @param source_url [String, nil] optional source URL
          # @param faq [String, nil] optional FAQ
          # @param deprecated [Boolean, nil] optional deprecation flag
          # @return [void]
          def call(mod_name:, description: nil, summary: nil, title: nil, category: nil, tags: nil, license: nil, homepage: nil, source_url: nil, faq: nil, deprecated: nil, **)
            # Build metadata hash
            metadata = build_metadata(
              description:,
              summary:,
              title:,
              category:,
              tags:,
              license:,
              homepage:,
              source_url:,
              faq:,
              deprecated:
            )

            # Validate at least one metadata field is provided
            if metadata.empty?
              say "At least one metadata option must be provided", prefix: :error
              say "Available options: --description, --summary, --title, --category, --tags, --license, --homepage, --source-url, --faq, --deprecated"
              raise Error, "No metadata options provided"
            end

            # Edit metadata via Portal
            portal.edit_mod(mod_name, **metadata)
            say "Metadata updated successfully!", prefix: :success
          end

          # Build metadata hash from options
          #
          # @param description [String, nil] description
          # @param summary [String, nil] summary
          # @param title [String, nil] title
          # @param category [String, nil] category
          # @param tags [Array<String>, nil] tags
          # @param license [String, nil] license
          # @param homepage [String, nil] homepage
          # @param source_url [String, nil] source URL
          # @param faq [String, nil] FAQ
          # @param deprecated [Boolean, nil] deprecation flag
          # @return [Hash] metadata hash with symbol keys
          private def build_metadata(description: nil, summary: nil, title: nil, category: nil, tags: nil, license: nil, homepage: nil, source_url: nil, faq: nil, deprecated: nil)
            metadata = {}
            metadata[:description] = description if description
            metadata[:summary] = summary if summary
            metadata[:title] = title if title
            metadata[:category] = category if category
            metadata[:tags] = tags if tags
            metadata[:license] = license if license
            metadata[:homepage] = homepage if homepage
            metadata[:source_url] = source_url if source_url
            metadata[:faq] = faq if faq
            metadata[:deprecated] = deprecated unless deprecated.nil?
            metadata
          end
        end
      end
    end
  end
end
