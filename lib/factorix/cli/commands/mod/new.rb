# frozen_string_literal: true

require "dry/cli"
require "erb"
require "pathname"
require_relative "../../../errors"
require_relative "../../../template_renderer"

module Factorix
  class CLI
    module Commands
      module Mod
        # Command for creating new MOD directory structure
        class New < Dry::CLI::Command
          desc "Create new MOD directory structure"

          argument :mod_name, type: :string, required: true, desc: "Name of the MOD to create"
          option :factorio_version, type: :string, default: "2.0", desc: "Factorio version"
          option :author_name, type: :string, desc: "Author name (defaults to current user login)"
          option :directory, type: :string, desc: "Directory to create MOD in (defaults to current directory)"
          option :git, type: :boolean, default: true, desc: "Initialize git repository"

          # Create new MOD directory structure
          # @param mod_name [String] Name of the MOD to create
          # @param options [Hash] Options for MOD creation
          # @option options [String] :factorio_version Factorio version
          # @option options [String] :author_name Author name
          # @option options [String] :directory Directory to create MOD in
          def call(mod_name:, **options)
            validate_mod_name(mod_name)

            factorio_version = options[:factorio_version] || "2.0"
            validate_factorio_version(factorio_version)

            target_dir = Pathname(options[:directory] || Dir.pwd)
            validate_target_directory(target_dir)

            new_mod_dir = target_dir / mod_name

            author_name = options[:author_name] || ENV["USER"] || ENV.fetch("USERNAME", nil)
            validate_author_name(author_name)

            # Atomically create MOD directory to prevent race conditions
            begin
              new_mod_dir.mkdir
            rescue Errno::EEXIST
              raise FileExistsError, "Directory already exists: #{new_mod_dir}"
            rescue Errno::EACCES
              raise DirectoryNotWritableError, "Permission denied: cannot create directory #{new_mod_dir}"
            rescue Errno::ENOSPC
              raise FileSystemError, "Not enough disk space to create directory #{new_mod_dir}"
            rescue => e
              raise FileSystemError, "Failed to create directory #{new_mod_dir}: #{e.message}"
            end

            # Wrap all creation operations in rescue block for cleanup
            begin
              create_mod_structure(new_mod_dir, mod_name, author_name, factorio_version)
            rescue => e
              # Clean up partially created directory on failure
              cleanup_partial_directory(new_mod_dir)
              raise e
            end

            initialize_git_repo(new_mod_dir) if options[:git]

            puts "MOD '#{mod_name}' created successfully in #{new_mod_dir}"
          end

          private def validate_mod_name(mod_name)
            if mod_name.length <= 3 || mod_name.length >= 50
              raise ValidationError, "MOD name must be between 4 and 49 characters long"
            end

            if mod_name.include?("..")
              raise ValidationError, "MOD name cannot contain relative path indicators"
            end

            if mod_name.include?(File::SEPARATOR)
              raise ValidationError, "MOD name cannot contain path separators"
            end

            if File::ALT_SEPARATOR && mod_name.include?(File::ALT_SEPARATOR)
              raise ValidationError, "MOD name cannot contain path separators"
            end

            return if mod_name.match?(/\A[a-zA-Z0-9_-]+\z/)

            raise ValidationError, "MOD name can only contain alphanumeric characters, underscores, and hyphens"
          end

          # Validate Factorio version
          # @param version [String] Factorio version to validate
          private def validate_factorio_version(version)
            return if version == "2.0"

            raise ValidationError, "Only Factorio version '2.0' is currently supported"
          end

          # Validate author name
          # @param author_name [String, nil] Author name to validate
          private def validate_author_name(author_name)
            return unless author_name.nil? || author_name.strip.empty?

            raise ValidationError,
              "Author name is required. Use --author-name option or set USER/USERNAME environment variable"
          end

          # Validate target directory exists and is safe
          # @param target_dir [Pathname] Target directory path
          private def validate_target_directory(target_dir)
            # Resolve and normalize the path to prevent path traversal
            begin
              resolved_path = target_dir.realpath
            rescue Errno::ENOENT
              raise DirectoryNotFoundError, "Target directory does not exist: #{target_dir}"
            end

            # Ensure it's actually a directory
            unless resolved_path.directory?
              raise DirectoryNotFoundError, "Target path is not a directory: #{target_dir}"
            end

            # Additional security check: ensure the resolved path doesn't contain suspicious patterns
            return unless resolved_path.to_s.include?("..")

            raise ValidationError, "Target directory path contains relative path indicators after resolution"
          end

          # Create MOD directory structure and files
          # @param new_mod_dir [Pathname] MOD directory path
          # @param mod_name [String] MOD name
          # @param author_name [String] Author name
          # @param factorio_version [String] Factorio version
          private def create_mod_structure(new_mod_dir, mod_name, author_name, factorio_version)
            # Initialize template renderer
            renderer = TemplateRenderer.new("mod/new", new_mod_dir)

            # Render all files
            current_date = Time.now.strftime("%Y-%m-%d")
            capitalized_name = capitalize_mod_name(mod_name)

            renderer.render(
              "info.json.erb",
              "info.json",
              mod_name:,
              author_name:,
              factorio_version:,
              capitalized_name:
            )

            renderer.render(
              "locale/en/mod_name.cfg.erb",
              "locale/en/#{mod_name}.cfg",
              mod_name:,
              capitalized_name:
            )

            renderer.render(
              "changelog.txt.erb",
              "changelog.txt",
              current_date:
            )

            renderer.render(
              "README.md.erb",
              "README.md",
              mod_name:
            )

            # Copy thumbnail.png
            renderer.copy_file("thumbnail.png", "thumbnail.png")

            # Copy empty Lua files
            renderer.copy_file("settings.lua", "settings.lua")
            renderer.copy_file("data.lua", "data.lua")
            renderer.copy_file("control.lua", "control.lua")
          end

          # Clean up partially created directory
          # @param dir [Pathname] Directory to clean up
          private def cleanup_partial_directory(dir)
            return unless dir.exist? && dir.directory?

            begin
              dir.rmtree
            rescue => e
              # Log cleanup failure but don't raise (original error is more important)
              warn "Warning: Failed to clean up partial directory #{dir}: #{e.message}"
            end
          end

          # Capitalize MOD name according to specification
          # @param mod_name [String] Original MOD name
          # @return [String] Capitalized MOD name
          private def capitalize_mod_name(mod_name)
            if mod_name.match?(/[A-Z]/)
              mod_name
            else
              mod_name.gsub(/\A[a-z]/, &:upcase).gsub(/[-_]/, " ")
            end
          end

          # Initialize git repository
          # @param new_mod_dir [Pathname] MOD directory path
          private def initialize_git_repo(new_mod_dir)
            Dir.chdir(new_mod_dir) do
              unless system("git", "init")
                raise CLIError, "Git repository initialization failed"
              end

              unless system("git", "add", ".")
                raise CLIError, "Git staging failed"
              end
            end
          end
        end
      end
    end
  end
end
