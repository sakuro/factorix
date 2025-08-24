# frozen_string_literal: true

require "erb"
require "pathname"

module Factorix
  # Template renderer for generating files from ERB templates
  class TemplateRenderer
    # Initialize template renderer
    # @param template_root [Pathname, String] Root directory for templates
    # @param output_root [Pathname, String] Root directory for output files
    def initialize(template_root, output_root)
      @template_root = Pathname(template_root)
      @output_root = Pathname(output_root)
    end

    # Render template file to output file
    # @param template_file [String] Template file path relative to template_root
    # @param output_file [String] Output file path relative to output_root
    # @param variables [Hash] Variables to substitute in template
    def render(template_file, output_file, **variables)
      template_path = @template_root / template_file
      output_path = @output_root / output_file

      unless template_path.exist?
        raise FileNotFoundError, "Template file not found: #{template_path}"
      end

      # Create output directory if it doesn't exist
      output_path.parent.mkpath

      # Read template content
      template_content = template_path.read

      # Render template using result_with_hash
      erb = ERB.new(template_content)
      rendered_content = erb.result_with_hash(variables)

      # Write output file
      output_path.write(rendered_content)
    end
  end
end
