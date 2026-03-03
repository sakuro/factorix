# frozen_string_literal: true

require "json"

module Factorix
  class CLI
    module Commands
      module Blueprint
        # Encode JSON to a Factorio blueprint string
        class Encode < Base
          desc "Encode JSON to a Factorio blueprint string"

          example [
            "                              # Encode from stdin",
            "decoded.json                  # Encode from file",
            "decoded.json -o blueprint.txt # Encode to file"
          ]

          argument :file, required: false, desc: "Path to JSON file (default: stdin)"
          option :output, aliases: ["-o"], desc: "Output file path (default: stdout)"

          # Execute the encode command
          #
          # @param file [String, nil] Path to JSON file
          # @param output [String, nil] Output file path
          # @return [void]
          def call(file: nil, output: nil, **)
            json_string = file ? Pathname(file).read : $stdin.read
            blueprint = Factorix::Blueprint.new(JSON.parse(json_string))
            blueprint_string = blueprint.encode

            if output
              Pathname(output).write(blueprint_string)
            else
              out.print blueprint_string
            end
          end
        end
      end
    end
  end
end
