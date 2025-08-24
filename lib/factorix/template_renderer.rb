# frozen_string_literal: true

require "erb"
require "pathname"
require_relative "errors"

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
      begin
        output_path.parent.mkpath
      rescue Errno::EACCES
        raise DirectoryNotWritableError, "Permission denied: cannot create directory #{output_path.parent}"
      rescue Errno::ENOSPC
        raise FileSystemError, "Not enough disk space to create directory #{output_path.parent}"
      rescue => e
        raise FileSystemError, "Failed to create output directory #{output_path.parent}: #{e.message}"
      end

      # Read template content
      begin
        template_content = template_path.read
      rescue Errno::EACCES
        raise FileNotFoundError, "Permission denied: cannot read template #{template_path}"
      rescue Errno::EIO, Errno::ENODEV
        raise FileSystemError, "I/O error reading template #{template_path}"
      rescue => e
        raise FileSystemError, "Failed to read template #{template_path}: #{e.message}"
      end

      # Render template using result_with_hash
      begin
        erb = ERB.new(template_content)
        rendered_content = erb.result_with_hash(variables)
      rescue SyntaxError => e
        raise TemplateError, "Template syntax error in #{template_file}: #{e.message}"
      rescue NameError => e
        raise TemplateError, "Template variable error in #{template_file}: #{e.message}"
      rescue => e
        raise TemplateError, "Template rendering error in #{template_file}: #{e.message}"
      end

      # Write output file
      begin
        output_path.write(rendered_content)
      rescue Errno::EACCES
        raise DirectoryNotWritableError, "Permission denied: cannot write to #{output_path}"
      rescue Errno::ENOSPC
        raise FileSystemError, "Not enough disk space to write #{output_path}"
      rescue => e
        raise FileSystemError, "Failed to write output file #{output_path}: #{e.message}"
      end
    end
  end
end
