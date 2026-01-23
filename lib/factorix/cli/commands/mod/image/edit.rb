# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Image
          # Edit MOD's image list on Factorio MOD Portal
          class Edit < Base
            include PortalSupport

            desc "Edit MOD's image list (reorder/remove images)"

            example [
              "some-mod abc123 def456   # Set image order (IDs from 'image list')"
            ]

            argument :mod_name, required: true, desc: "MOD name"
            argument :image_ids, type: :array, required: true, desc: "Image IDs in desired order"

            # Execute the edit command
            #
            # @param mod_name [String] the MOD name
            # @param image_ids [Array<String>] array of image IDs
            # @return [void]
            def call(mod_name:, image_ids:, **)
              # Edit images via Portal
              portal.edit_mod_images(mod_name, image_ids)

              say "Image list updated successfully!", prefix: :success
              say "Total images: #{image_ids.size}", prefix: :info
            end
          end
        end
      end
    end
  end
end
