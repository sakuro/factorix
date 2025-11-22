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
            include Import[:portal]

            desc "List images for a MOD"

            argument :mod_name, type: :string, required: true, desc: "MOD name"

            option :json, type: :boolean, default: false, desc: "Output in JSON format"

            # Execute the list command
            #
            # @param mod_name [String] the mod name
            # @param json [Boolean] output in JSON format
            # @return [void]
            def call(mod_name:, json:, **)
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

              if json
                say JSON.pretty_generate(images)
              else
                output_table(images)
              end
            end

            private def output_table(images)
              if images.empty?
                say "No images found"
                return
              end

              id_width = [images.map {|i| i[:id].length }.max, 2].max
              thumb_width = [images.map {|i| i[:thumbnail].length }.max, 9].max

              say "%-#{id_width}s  %-#{thumb_width}s  %s" % %w[ID THUMBNAIL URL]

              images.each do |image|
                say "%-#{id_width}s  %-#{thumb_width}s  %s" % [image[:id], image[:thumbnail], image[:url]]
              end
            end
          end
        end
      end
    end
  end
end
