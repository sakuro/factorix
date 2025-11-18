# frozen_string_literal: true

module Factorix
  module Dependency
    # Represents a MOD node in the dependency graph
    #
    # Each node represents a MOD with its version, installation state,
    # and enabled state. Operations can be planned on nodes (:enable,
    # :disable, :install, :uninstall).
    class Node
      attr_reader :mod          # MOD object (identifier)
      attr_reader :version      # Types::MODVersion
      attr_accessor :enabled    # Boolean - is the MOD enabled in mod-list.json?
      attr_accessor :installed  # Boolean - is the MOD installed in mod_dir?
      attr_accessor :operation  # Symbol - planned operation (:enable, :disable, :install, :uninstall, nil)

      # Create a new MOD node
      #
      # @param mod [Factorix::MOD] The MOD identifier
      # @param version [Factorix::Types::MODVersion] The MOD version
      # @param enabled [Boolean] Whether the MOD is enabled (default: false)
      # @param installed [Boolean] Whether the MOD is installed (default: false)
      # @param operation [Symbol, nil] Planned operation (default: nil)
      def initialize(mod:, version:, enabled: false, installed: false, operation: nil)
        @mod = mod
        @version = version
        @enabled = enabled
        @installed = installed
        @operation = operation
      end

      # Check if the MOD is enabled
      #
      # @return [Boolean]
      def enabled? = @enabled

      # Check if the MOD is installed
      #
      # @return [Boolean]
      def installed? = @installed

      # Check if an operation is planned for this node
      #
      # @return [Boolean]
      def operation? = !@operation.nil?

      # String representation of the node
      #
      # @return [String]
      def to_s
        state_flags = []
        state_flags << "enabled" if @enabled
        state_flags << "installed" if @installed
        state_flags << "op:#{@operation}" if @operation

        state = state_flags.empty? ? "new" : state_flags.join(", ")
        "#{@mod.name} v#{@version} (#{state})"
      end

      # Detailed inspection string
      #
      # @return [String]
      def inspect = "#<#{self.class.name} #{self}>"
    end
  end
end
