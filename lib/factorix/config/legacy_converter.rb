# frozen_string_literal: true

require "perfect_toml"

module Factorix
  class Config
    # Converts a legacy Ruby-DSL configuration file to TOML
    #
    # The legacy format was an instance_eval'd script calling
    # `configure {|config| config.section.key = value }` (dry-configurable).
    # The script is evaluated once against a recorder that captures the
    # assignments, and the result is rendered as TOML for the user to save.
    class LegacyConverter
      # Convert a legacy configuration file to a TOML document
      #
      # @param path [Pathname] path to the legacy config.rb
      # @return [String] equivalent TOML document
      def self.convert(path) = new.convert(path)

      # @param path [Pathname] path to the legacy config.rb
      # @return [String] equivalent TOML document
      def convert(path)
        recorder = Recorder.new
        Context.new(recorder).instance_eval(path.read, path.to_s)
        PerfectTOML.generate(sanitize(recorder.to_h))
      end

      private def sanitize(value)
        case value
        when Hash
          value.filter_map {|key, val|
            sanitized = sanitize(val)
            [key.to_s, sanitized] unless sanitized.nil?
          }.to_h
        when Symbol, Pathname
          value.to_s
        else
          value
        end
      end

      # Evaluation context for the legacy script
      class Context
        # @param recorder [Recorder] recorder receiving the assignments
        def initialize(recorder) = @recorder = recorder

        # The legacy DSL entry point
        #
        # @yieldparam config [Recorder] assignment recorder
        # @return [void]
        def configure
          yield @recorder
        end
      end
      private_constant :Context

      # Records nested attribute assignments as a hash tree
      class Recorder
        def initialize
          @values = {}
          @children = {}
        end

        # @return [Hash{Symbol => untyped}] captured assignments
        def to_h = @children.transform_values(&:to_h).merge(@values)

        private def method_missing(name, *args)
          name_string = name.to_s
          if name_string.end_with?("=")
            @values[name_string.delete_suffix("=").to_sym] = args.first
          else
            @children[name] ||= Recorder.new
          end
        end

        private def respond_to_missing?(_name, _include_private=false) = true
      end
      private_constant :Recorder
    end
  end
end
