# frozen_string_literal: true

module Factorix
  module SerDes
    # Deserialize data from binary format
    #
    # This class provides methods to deserialize various data types from Factorio's
    # binary file format, following the specifications documented in the Factorio wiki.
    class Deserializer
      # @!parse
      #   # @return [Dry::Logger::Dispatcher]
      #   attr_reader :logger
      include Import[:logger]

      # Create a new Deserializer instance
      #
      # @param stream [IO] An IO-like object that responds to #read
      # @param logger [Dry::Logger::Dispatcher] optional logger
      # @raise [ArgumentError] If the stream doesn't respond to #read
      def initialize(stream, logger: nil)
        super(logger:)
        raise ArgumentError, "can't read from the given argument" unless stream.respond_to?(:read)

        @stream = stream
        logger.debug "Initializing Deserializer"
      end

      # Read raw bytes from the stream
      #
      # @param length [Integer] Number of bytes to read
      # @raise [Factorix::InvalidLengthError] If length is nil or negative
      # @raise [EOFError] If end of file is reached before reading length bytes
      # @return [String] Binary data read
      def read_bytes(length)
        raise InvalidLengthError, "nil length" if length.nil?
        raise InvalidLengthError, "negative length #{length}" if length.negative?
        return +"" if length.zero?

        bytes = @stream.read(length)
        if bytes.nil? || bytes.size < length
          logger.debug("Unexpected EOF", requested_bytes: length)
          raise EOFError
        end

        bytes
      end

      # Read an unsigned 8-bit integer
      #
      # @return [Integer] 8-bit unsigned integer
      def read_u8 = read_bytes(1).unpack1("C")

      # Read an unsigned 16-bit integer
      #
      # @return [Integer] 16-bit unsigned integer
      def read_u16 = read_bytes(2).unpack1("v")

      # Read an unsigned 32-bit integer
      #
      # @return [Integer] 32-bit unsigned integer
      def read_u32 = read_bytes(4).unpack1("V")

      # Read a space-optimized 16-bit unsigned integer
      #
      # @see https://wiki.factorio.com/Data_types#Space_Optimized
      # @return [Integer] 16-bit unsigned integer
      def read_optim_u16
        byte = read_u8
        byte == 0xFF ? read_u16 : byte
      end

      # Read a space-optimized 32-bit unsigned integer
      #
      # @see https://wiki.factorio.com/Data_types#Space_Optimized
      # @return [Integer] 32-bit unsigned integer
      def read_optim_u32
        byte = read_u8
        byte == 0xFF ? read_u32 : byte
      end

      # Read a tuple of 16-bit unsigned integers
      #
      # @param length [Integer] Number of integers to read
      # @return [Array<Integer>] Array of 16-bit unsigned integers
      def read_u16_tuple(length) = Array.new(length) { read_u16 }

      # Read a boolean value
      #
      # @return [Boolean] Boolean value
      def read_bool = read_u8 != 0

      # Read a string
      #
      # @return [String] String read
      def read_str
        length = read_optim_u32
        read_bytes(length).force_encoding(Encoding::UTF_8)
      end

      # Read a string property
      #
      # @see https://wiki.factorio.com/Property_tree#String
      # @return [String] String property
      def read_str_property = read_bool ? "" : read_str

      # Read a double-precision floating point number
      #
      # @see https://wiki.factorio.com/Property_tree#Number
      # @return [Float] Double-precision floating point number
      def read_double = read_bytes(8).unpack1("d")

      # Read a GameVersion object
      #
      # @return [GameVersion] GameVersion object
      def read_game_version = Types::GameVersion.from_numbers(read_u16, read_u16, read_u16, read_u16)

      # Read a MODVersion object
      #
      # @return [MODVersion] MODVersion object
      def read_mod_version = Types::MODVersion.from_numbers(read_optim_u16, read_optim_u16, read_optim_u16)

      # Read a signed long integer (8 bytes)
      #
      # @return [Integer] Signed long integer
      def read_long = read_bytes(8).unpack1("q<")

      # Read an unsigned long integer (8 bytes)
      #
      # @return [Integer] Unsigned long integer
      def read_unsigned_long = read_bytes(8).unpack1("Q<")

      # Read a dictionary
      #
      # @see https://wiki.factorio.com/Property_tree#Dictionary
      # @return [Hash] Dictionary of key-value pairs
      def read_dictionary
        length = read_u32
        logger.debug("Reading dictionary", length:)
        length.times.each_with_object({}) do |_i, dict|
          key = read_str_property
          dict[key] = read_property_tree
        end
      end

      # Read a list
      # This type is identical to dictionary
      #
      # @see https://wiki.factorio.com/Property_tree#List
      alias read_list read_dictionary

      # Read a property tree
      #
      # @raise [Factorix::UnknownPropertyType] If the property type is not supported
      # @return [Object] Object read
      def read_property_tree
        type = read_u8
        _any_type_flag = read_bool
        logger.debug("Reading property tree", type:)

        case type
        when 0
          # Handle type 0 - None (null value)
          #
          # @see https://wiki.factorio.com/Property_tree
          nil
        when 1
          read_bool
        when 2
          read_double
        when 3
          read_str_property
        when 4
          read_list
        when 5
          read_dictionary
        when 6
          # Handle type 6 - Signed integer
          #
          # @see https://wiki.factorio.com/Property_tree
          SignedInteger.new(read_long)
        when 7
          # Handle type 7 - Unsigned integer
          #
          # @see https://wiki.factorio.com/Property_tree
          UnsignedInteger.new(read_unsigned_long)
        else
          logger.debug("Unknown property type", type:)
          raise UnknownPropertyType, "Unknown property type: #{type}"
        end
      end

      # Check if the stream is at EOF
      #
      # @return [Boolean] True if at end of file, false otherwise
      def eof? = @stream.eof?
    end
  end
end
