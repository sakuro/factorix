# frozen_string_literal: true

module Factorix
  class CLI
    module Commands
      module MOD
        module Changelog
          # Validate the structure of a MOD changelog file
          class Check < Base
            desc "Validate MOD changelog structure"

            option :release, type: :flag, default: false, desc: "Disallow Unreleased section"
            option :changelog, default: "changelog.txt", desc: "Path to changelog file"
            option :info_json, default: "info.json", desc: "Path to info.json file"

            # @param release [Boolean] disallow Unreleased section
            # @param changelog [String] path to changelog file
            # @param info_json [String] path to info.json file
            # @return [void]
            def call(release: false, changelog: "changelog.txt", info_json: "info.json", **)
              errors = []

              log = parse_changelog(Pathname(changelog), errors)
              return report(errors) unless log

              validate_unreleased_position(log, errors)
              validate_version_order(log, errors)

              if release
                validate_release_mode(log, Pathname(info_json), errors)
              end

              report(errors)
            end

            private def parse_changelog(path, errors)
              Factorix::Changelog.load(path)
            rescue ChangelogParseError => e
              errors << "Failed to parse changelog: #{e.message}"
              nil
            end

            private def validate_unreleased_position(log, errors)
              log.sections.each_with_index do |section, index|
                next unless section.version == Factorix::Changelog::UNRELEASED
                next if index.zero?

                errors << "Unreleased section must be the first section"
                break
              end
            end

            private def validate_version_order(log, errors)
              versioned = log.sections.select {|s| s.version.is_a?(MODVersion) }
              versioned.each_cons(2) do |a, b|
                next if a.version > b.version

                errors << "Versions are not in descending order: #{a.version} should be greater than #{b.version}"
              end
            end

            private def validate_release_mode(log, info_json_path, errors)
              if log.sections.any? {|s| s.version == Factorix::Changelog::UNRELEASED }
                errors << "Unreleased section is not allowed in release mode"
              end

              validate_info_json_version(log, info_json_path, errors)
            end

            private def validate_info_json_version(log, info_json_path, errors)
              unless info_json_path.exist?
                errors << "info.json not found: #{info_json_path}"
                return
              end

              info = InfoJSON.from_json(info_json_path.read)
              first_versioned = log.sections.find {|s| s.version.is_a?(MODVersion) }
              return unless first_versioned

              return if info.version == first_versioned.version

              errors << "info.json version (#{info.version}) does not match first changelog version (#{first_versioned.version})"
            end

            private def report(errors)
              if errors.empty?
                say "Changelog is valid", prefix: :success
              else
                say "Changelog validation failed:", prefix: :error
                errors.each {|msg| say "  - #{msg}" }
                raise ValidationError, "Changelog validation failed"
              end
            end
          end
        end
      end
    end
  end
end
