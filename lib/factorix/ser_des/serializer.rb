# frozen_string_literal: true

module Factorix
  module SerDes
    # Serialize data to binary format
    #
    # This class provides methods to serialize various data types to Factorio's
    # binary file format, following the specifications documented in the Factorio wiki.
    class Serializer
      # @!parse
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Import[:logger]

      # Create a new Serializer instance
      #
      # @param stream [IO] An IO-like object that responds to #write
      # @param logger [Dry::Logger::Dispatcher] optional logger
      # @raise [ArgumentError] If the stream doesn't respond to #write
      def initialize(stream, logger: nil)
        super(logger:)
        raise ArgumentError, "can't write to the given argument" unless stream.respond_to?(:write)

        @stream = stream
        logger.debug "Initializing Serializer"
      end

      # Write raw bytes to the stream
      #
      # @param data [String] Binary data to write
      # @raise [ArgumentError] If data is nil
      # @return [void]
      def write_bytes(data)
        raise ArgumentError if data.nil?
        return if data.empty?

        @stream.write(data)
      end

      # Write an unsigned 8-bit integer
      #
      # @param uint8 [Integer] 8-bit unsigned integer
      # @return [void]
      def write_u8(uint8) = write_bytes([uint8].pack("C"))

      # Write an unsigned 16-bit integer
      #
      # @param uint16 [Integer] 16-bit unsigned integer
      # @return [void]
      def write_u16(uint16) = write_bytes([uint16].pack("v"))

      # Write an unsigned 32-bit integer
      #
      # @param uint32 [Integer] 32-bit unsigned integer
      # @return [void]
      def write_u32(uint32) = write_bytes([uint32].pack("V"))

      # Write a space-optimized 16-bit unsigned integer
      #
      # @see https://wiki.factorio.com/Data_types#Space_Optimized
      # @param uint16 [Integer] 16-bit unsigned integer
      # @return [void]
      def write_optim_u16(uint16)
        if uint16 < 0xFF
          write_u8(uint16 & 0xFF)
        else
          write_u8(0xFF)
          write_u16(uint16)
        end
      end

      # Write a space-optimized 32-bit unsigned integer
      #
      # @see https://wiki.factorio.com/Data_types#Space_Optimized
      # @param uint32 [Integer] 32-bit unsigned integer
      # @return [void]
      def write_optim_u32(uint32)
        if uint32 < 0xFF
          write_u8(uint32 & 0xFF)
        else
          write_u8(0xFF)
          write_u32(uint32)
        end
      end

      # Write a boolean value
      #
      # @param bool [Boolean] Boolean value
      # @return [void]
      def write_bool(bool) = write_u8(bool ? 0x01 : 0x00)

      # Write a string
      #
      # @param str [String] String to write (must be UTF-8 encoded)
      # @raise [ArgumentError] If the string is not UTF-8 encoded
      # @return [void]
      def write_str(str)
        if str.encoding != Encoding::UTF_8 && !(str.encoding == Encoding::ASCII_8BIT && str.force_encoding(Encoding::UTF_8).valid_encoding?)
          logger.debug("String encoding error", expected: "UTF-8", got: str.encoding.name)
          raise ArgumentError, "String must be UTF-8 encoded, got #{str.encoding}"
        end

        write_optim_u32(str.bytesize)
        write_bytes(str.b)
      end

      # Write a string property
      #
      # @see https://wiki.factorio.com/Property_tree#String
      # @param str [String] String to write
      # @return [void]
      def write_str_property(str)
        if str.empty?
          write_bool(true)
        else
          write_bool(false)
          write_str(str)
        end
      end

      # Write a double-precision floating point number
      #
      # @see https://wiki.factorio.com/Property_tree#Number
      # @param dbl [Float] Double-precision floating point number
      # @return [void]
      def write_double(dbl) = write_bytes([dbl].pack("d"))

      # Write a GameVersion object
      #
      # @param game_version [GameVersion] GameVersion object
      # @return [void]
      def write_game_version(game_version) = game_version.to_a.each {|u16| write_u16(u16) }

      # Write a MODVersion object
      #
      # @param mod_version [MODVersion] MODVersion object
      # @return [void]
      def write_mod_version(mod_version) = mod_version.to_a.each {|u16| write_optim_u16(u16) }

      # Write a list
      #
      # @see https://wiki.factorio.com/Property_tree#List
      # @param list [Array] List of objects
      # @return [void]
      def write_list(list)
        logger.debug("Writing list", size: list.size)
        write_optim_u32(list.size)
        list.each {|e| write_property_tree(e) }
      end

      # Write a dictionary
      #
      # @see https://wiki.factorio.com/Property_tree#Dictionary
      # @param dict [Hash] Dictionary of key-value pairs
      # @return [void]
      def write_dictionary(dict)
        logger.debug("Writing dictionary", size: dict.size)
        write_u32(dict.size)
        dict.each do |(key, value)|
          write_str_property(key)
          write_property_tree(value)
        end
      end

      # Write a signed long integer (8 bytes)
      #
      # @param long [Integer] Signed long integer
      # @return [void]
      def write_long(long) = write_bytes([long].pack("q<"))

      # Write an unsigned long integer (8 bytes)
      #
      # @param ulong [Integer] Unsigned long integer
      # @return [void]
      def write_unsigned_long(ulong) = write_bytes([ulong].pack("Q<"))

      # Write a property tree
      #
      # @param obj [Object] Object to write
      # @raise [Factorix::UnknownPropertyType] If the object type is not supported
      # @return [void]
      def write_property_tree(obj)
        logger.debug("Writing property tree", type: obj.class.name)
        case obj
        when nil
          # Type 0 - None (null value)
          write_u8(0)
          write_bool(false)
        when true, false
          # Type 1 - Boolean
          write_u8(1)
          write_bool(false)
          write_bool(obj)
        when Float
          # Type 2 - Number (double)
          write_u8(2)
          write_bool(false)
          write_double(obj)
        when String
          # Type 3 - String
          write_u8(3)
          write_bool(false)
          write_str_property(obj)
        when Array
          # Type 4 - List
          write_u8(4)
          write_bool(false)
          write_list(obj)
        when Hash
          # Type 5 - Dictionary
          write_u8(5)
          write_bool(false)
          write_dictionary(obj)
        when Types::SignedInteger
          # Type 6 - Signed integer
          write_u8(6)
          write_bool(false)
          write_long(obj.__getobj__)
        when Types::UnsignedInteger
          # Type 7 - Unsigned integer
          write_u8(7)
          write_bool(false)
          write_unsigned_long(obj.__getobj__)
        else
          logger.debug("Unknown property type", type: obj.class.name)
          raise UnknownPropertyType, "Unknown property type: #{obj.class}"
        end
      end
    end
  end
end
