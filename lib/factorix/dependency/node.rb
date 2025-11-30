# frozen_string_literal: true

module Factorix
  module Dependency
    Node = Data.define(:mod, :version, :enabled, :installed, :operation)

    # Represents a MOD node in the dependency graph
    #
    # Each node represents a MOD with its version, installation state,
    # and enabled state. Operations can be planned on nodes (:enable,
    # :disable, :install, :uninstall).
    class Node
      # @!attribute [r] mod
      #   @return [Factorix::MOD] The MOD identifier
      # @!attribute [r] version
      #   @return [Factorix::MODVersion] The MOD version
      # @!attribute [r] enabled
      #   @return [Boolean] Whether the MOD is enabled
      # @!attribute [r] installed
      #   @return [Boolean] Whether the MOD is installed
      # @!attribute [r] operation
      #   @return [Symbol, nil] Planned operation (:enable, :disable, :install, :uninstall, nil)

      def initialize(mod:, version:, enabled: false, installed: false, operation: nil) = super

      # Check if the MOD is enabled
      #
      # @return [Boolean]
      def enabled? = enabled

      # Check if the MOD is installed
      #
      # @return [Boolean]
      def installed? = installed

      # Check if an operation is planned for this node
      #
      # @return [Boolean]
      def operation? = !operation.nil?

      # String representation of the node
      #
      # @return [String]
      def to_s
        state_flags = []
        state_flags << "enabled" if enabled
        state_flags << "installed" if installed
        state_flags << "op:#{operation}" if operation

        state = state_flags.empty? ? "new" : state_flags.join(", ")
        "#{mod} v#{version} (#{state})"
      end

      # Detailed inspection string
      #
      # @return [String]
      def inspect = "#<#{self.class.name} #{self}>"
    end
  end
end
