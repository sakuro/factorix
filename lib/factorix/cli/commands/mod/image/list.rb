# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Image
          # List images for a MOD on Factorio MOD Portal
          class List < Base
            # @!parse
            #   # @return [Portal]
            #   attr_reader :portal
            include Factorix::Import[:portal]

            desc "List images for a MOD"

            argument :mod_name, type: :string, required: true, desc: "MOD name"

            # Execute the list command
            #
            # @param mod_name [String] the mod name
            # @return [void]
            def call(mod_name:, **)
              # Get full mod info to retrieve images
              mod_info = portal.get_mod_full(mod_name)

              images = if mod_info.detail&.images&.any?
                         mod_info.detail.images.map do |image|
                           {
                             id: image.id,
                             thumbnail: image.thumbnail.to_s,
                             url: image.url.to_s
                           }
                         end
                       else
                         []
                       end

              puts JSON.pretty_generate(images)
            end
          end
        end
      end
    end
  end
end
