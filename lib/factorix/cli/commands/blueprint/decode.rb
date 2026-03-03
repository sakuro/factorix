# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module Blueprint
        # Decode a Factorio blueprint string to JSON
        class Decode < Base
          desc "Decode a Factorio blueprint string to JSON"

          example [
            "                              # Decode from stdin",
            "blueprint.txt                 # Decode from file",
            "blueprint.txt -o decoded.json # Decode to file"
          ]

          argument :file, required: false, desc: "Path to file containing blueprint string (default: stdin)"
          option :output, aliases: ["-o"], desc: "Output file path (default: stdout)"

          # Execute the decode command
          #
          # @param file [String, nil] Path to file containing blueprint string
          # @param output [String, nil] Output file path
          # @return [void]
          def call(file: nil, output: nil, **)
            blueprint_string = file ? Pathname(file).read.strip : $stdin.read.strip
            blueprint = Factorix::Blueprint.decode(blueprint_string)
            json_string = blueprint.to_json

            if output
              Pathname(output).write(json_string)
            else
              out.puts json_string
            end
          end
        end
      end
    end
  end
end
