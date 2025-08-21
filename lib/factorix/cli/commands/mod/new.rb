# frozen_string_literal: true

require "erb"
require "fileutils"
require "pathname"
require "dry/cli"

require_relative "../../../errors"

module Factorix
  class CLI
    module Commands
      module Mod
        # Command to create a new Factorio MOD
        class New < Dry::CLI::Command
          desc "Create a new Factorio MOD"

          argument :mod_name, required: true, desc: "Name of the MOD to create"
          option :factorio_version, default: "2.0", desc: "Factorio version (default: 2.0)"
          option :author_name, desc: "Author name (default: current user)"
          option :directory, desc: "Target directory (default: current directory)"

          example [
            "my-awesome-mod",
            "my-mod --author-name 'John Doe'",
            "my-mod --directory ~/factorio-mods"
          ]

          # Create a new Factorio MOD
          #
          # @param mod_name [String] Name of the MOD to create
          # @param options [Hash] Command options
          # @option options [String] :factorio_version Factorio version
          # @option options [String] :author_name Author name
          # @option options [String] :directory Target directory
          def call(mod_name:, **options)
            validate_mod_name(mod_name)
            validate_factorio_version(options[:factorio_version])

            target_dir = determine_target_directory(options[:directory])
            author_name = determine_author_name(options[:author_name])
            mod_directory = create_mod_directory(target_dir, mod_name)

            create_mod_structure(mod_directory, mod_name, options[:factorio_version], author_name)
            initialize_git_repository(mod_directory)

            puts "Successfully created MOD: #{mod_name}"
          end

          private

          def validate_mod_name(mod_name)
            if mod_name.length <= 3 || mod_name.length >= 50
              raise CLIError, "MOD name must be longer than 3 characters and shorter than 50 characters"
            end

            unless mod_name.match?(/\A[a-zA-Z0-9_-]+\z/)
              raise CLIError, "MOD name can only contain letters, numbers, underscores, and hyphens"
            end
          end

          def validate_factorio_version(version)
            unless version == "2.0"
              raise CLIError, "Only Factorio version 2.0 is currently supported"
            end
          end

          def determine_target_directory(directory)
            target_dir = Pathname(directory || Dir.pwd)
            raise DirectoryNotFoundError, "Directory does not exist: #{target_dir}" unless target_dir.exist?
            raise DirectoryNotWritableError, "Directory is not writable: #{target_dir}" unless target_dir.writable?

            target_dir
          end

          def determine_author_name(author_name)
            author_name || ENV.fetch("USER", ENV.fetch("USERNAME", "unknown"))
          end

          def create_mod_directory(target_dir, mod_name)
            mod_directory = target_dir / mod_name
            raise DirectoryExistsError, "Directory already exists: #{mod_directory}" if mod_directory.exist?

            FileUtils.mkdir_p(mod_directory)
            mod_directory
          end

          def create_mod_structure(mod_directory, mod_name, factorio_version, author_name)
            # Create locale directory structure
            locale_dir = mod_directory / "locale" / "en"
            FileUtils.mkdir_p(locale_dir)

            # Create files
            create_info_json(mod_directory, mod_name, factorio_version, author_name)
            create_locale_cfg(locale_dir, mod_name)
            create_changelog_txt(mod_directory)
            create_readme_md(mod_directory, mod_name)
            create_thumbnail_png(mod_directory)
            create_lua_files(mod_directory)
          end

          def create_info_json(mod_directory, mod_name, factorio_version, author_name)
            template = ERB.new(<<~JSON)
              {
                "name": "<%= mod_name %>",
                "version": "0.0.1",
                "title": "<%= capitalize_mod_name(mod_name) %>",
                "author": "<%= author_name %>",
                "factorio_version": "<%= factorio_version %>",
                "dependencies": []
              }
            JSON

            content = template.result(binding)
            (mod_directory / "info.json").write(content)
          end

          def create_locale_cfg(locale_dir, mod_name)
            template = ERB.new(<<~CFG)
              [mod-name]
              <%= mod_name %>=<%= capitalize_mod_name(mod_name) %>

              [mod-description]
              <%= mod_name %>=<%= capitalize_mod_name(mod_name) %>
            CFG

            content = template.result(binding)
            (locale_dir / "#{mod_name}.cfg").write(content)
          end

          def create_changelog_txt(mod_directory)
            current_date = Time.now.strftime("%Y-%m-%d")
            template = ERB.new(<<~CHANGELOG)
              ---------------------------------------------------------------------------------------------------
              Version: 0.0.1
              Date: <%= current_date %>
              Changes:
                - Initial release
            CHANGELOG

            content = template.result(binding)
            (mod_directory / "changelog.txt").write(content)
          end

          def create_readme_md(mod_directory, mod_name)
            template = ERB.new(<<~MARKDOWN)
              # <%= mod_name %>
            MARKDOWN

            content = template.result(binding)
            (mod_directory / "README.md").write(content)
          end

          def create_thumbnail_png(mod_directory)
            # Create a simple 144x144 gray PNG thumbnail
            target_thumbnail = mod_directory / "thumbnail.png"
            
            # Minimal PNG file content for 144x144 gray image (#999999)
            # This is a base64 encoded minimal PNG
            require "base64"
            
            # This creates a very simple 1x1 gray PNG that will be scaled
            gray_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkWMaIHgADfAGVpWFUbQAAAABJRU5ErkJggg=="
            png_content = Base64.decode64(gray_png_base64)
            
            target_thumbnail.binwrite(png_content)
          end

          def create_lua_files(mod_directory)
            # Create empty Lua files
            %w[settings.lua data.lua control.lua].each do |filename|
              (mod_directory / filename).write("")
            end
          end

          def initialize_git_repository(mod_directory)
            Dir.chdir(mod_directory) do
              system("git", "init", out: File::NULL, err: File::NULL)
              system("git", "add", ".", out: File::NULL, err: File::NULL)
              system("git", "commit", "-m", ":new: Initial commit", out: File::NULL, err: File::NULL)
            end
          end

          def capitalize_mod_name(mod_name)
            if mod_name.match?(/[A-Z]/)
              # Already contains uppercase letters, use as-is
              mod_name
            else
              # Convert first letter to uppercase and replace - and _ with spaces
              mod_name.split(/[-_]/).map(&:capitalize).join(" ")
            end
          end
        end
      end
    end
  end
end