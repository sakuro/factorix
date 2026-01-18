# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        # Upload MOD to Factorio MOD Portal (handles both new and update)
        class Upload < Base
          # @!parse
          #   # @return [Portal]
          #   attr_reader :portal
          include Import[:portal]

          desc "Upload MOD to Factorio MOD Portal (handles both new and update)"

          example [
            "my-mod_1.0.0.zip                           # Upload MOD",
            "my-mod_1.0.0.zip --category automation     # Upload with category"
          ]

          argument :file, required: true, desc: "Path to MOD zip file"
          option :description, desc: "Markdown description"
          option :category, desc: "MOD category"
          option :license, desc: "License identifier"
          option :source_url, desc: "Repository URL"

          # Execute the upload command
          #
          # @param file [String] path to MOD zip file
          # @param description [String, nil] optional description
          # @param category [String, nil] optional category
          # @param license [String, nil] optional license
          # @param source_url [String, nil] optional source URL
          # @return [void]
          # @raise [InvalidArgumentError] if file does not exist, is not a file, or is not a .zip file
          # @raise [FileFormatError] if zip is invalid or info.json is missing/malformed
          def call(file:, description: nil, category: nil, license: nil, source_url: nil, **)
            file_path = Pathname(file)

            raise InvalidArgumentError, "File not found: #{file}" unless file_path.exist?
            raise InvalidArgumentError, "Not a file: #{file}" unless file_path.file?
            raise InvalidArgumentError, "File must be a .zip file" if file_path.extname.casecmp(".zip").nonzero?

            mod_name = extract_mod_name(file_path)
            metadata = build_metadata(description:, category:, license:, source_url:)

            presenter = Progress::Presenter.new(title: "\u{1F4E4} Uploading #{file_path.basename}", output: err)

            uploader = portal.mod_management_api.uploader
            handler = Progress::UploadHandler.new(presenter)
            uploader.subscribe(handler)

            begin
              portal.upload_mod(mod_name, file_path, **metadata)
              say "Upload completed successfully!", prefix: :success
            ensure
              uploader.unsubscribe(handler)
            end
          end

          # Extract MOD name from info.json inside zip file
          #
          # @param file_path [Pathname] path to zip file
          # @return [String] MOD name from info.json
          # @raise [FileFormatError] if info.json not found or invalid
          private def extract_mod_name(file_path)
            info = InfoJSON.from_zip(file_path)
            info.name
          end

          # Build metadata hash from options
          #
          # @param description [String, nil] description
          # @param category [String, nil] category
          # @param license [String, nil] license
          # @param source_url [String, nil] source URL
          # @return [Hash] metadata hash with symbol keys
          private def build_metadata(description: nil, category: nil, license: nil, source_url: nil)
            metadata = {}
            metadata[:description] = description if description
            metadata[:category] = category if category
            metadata[:license] = license if license
            metadata[:source_url] = source_url if source_url
            metadata
          end
        end
      end
    end
  end
end
