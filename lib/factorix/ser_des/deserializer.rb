# frozen_string_literal: true

module Factorix
  module SerDes
    # Deserialize data from binary format
    class Deserializer
      # Create a new Deserializer instance
      #
      # @param stream [IO] An IO-like object that responds to #read
      # @raise [ArgumentError] If the stream doesn't respond to #read
      def initialize(stream)
        raise ArgumentError, "can't read from the given argument" unless stream.respond_to?(:read)

        @stream = stream
      end

      # Read raw bytes from the stream
      #
      # @param length [Integer] Number of bytes to read
      # @raise [ArgumentError] If length is nil or negative
      # @raise [EOFError] If end of file is reached before reading length bytes
      # @return [String] Binary data read
      def read_bytes(length)
        raise ArgumentError, "nil length" if length.nil?
        raise ArgumentError, "negative length" if length.negative?
        return +"" if length.zero?

        bytes = @stream.read(length)
        raise EOFError if bytes.nil? || bytes.size < length

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

      # Read a Version64 object
      #
      # @return [Version64] Version64 object
      def read_version64 = Factorix::SerDes::Version64[read_u16, read_u16, read_u16, read_u16]

      # Read a Version24 object
      #
      # @return [Version24] Version24 object
      def read_version24 = Factorix::SerDes::Version24[read_optim_u16, read_optim_u16, read_optim_u16]

      # Read a list
      #
      # @see https://wiki.factorio.com/Property_tree#List
      # @return [Array] List of objects
      def read_list
        length = read_optim_u32
        Array(length) { read_property_tree }
      end

      # Read a dictionary
      #
      # @see https://wiki.factorio.com/Property_tree#Dictionary
      # @return [Hash] Dictionary of key-value pairs
      def read_dictionary
        length = read_u32
        length.times.each_with_object({}) do |_i, dict|
          key = read_str_property
          dict[key] = read_property_tree
        end
      end

      RGBA = %w[r g b a].freeze
      private_constant :RGBA
      RGBA_SORTED = RGBA.sort.freeze
      private_constant :RGBA_SORTED

      # Read a property tree
      #
      # @raise [UnknownPropertyType] If the property type is not supported
      # @return [Object] Object read
      def read_property_tree
        type = read_u8
        _any_type_flag = read_bool

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
          dict = read_dictionary
          if dict.keys.sort == RGBA_SORTED
            # convert {"r": RR, "g": GG, "b": BB, "a": AA } to "rgba:RRGGBBAA"
            "rgba:%02x%02x%02x%02x" % RGBA.map {|k| dict[k] * 255 }
          else
            dict
          end
        when 6
          # Handle type 6 - Signed integer
          #
          # @see https://wiki.factorio.com/Property_tree
          read_long
        when 7
          # Handle type 7 - Unsigned integer
          #
          # @see https://wiki.factorio.com/Property_tree
          read_unsigned_long
        else
          raise Factorix::UnknownPropertyType, "Unknown property type: #{type}"
        end
      end

      # Read a signed long integer (8 bytes)
      #
      # @return [Integer] Signed long integer
      def read_long
        read_bytes(8).unpack1("q<")
      end

      # Read an unsigned long integer (8 bytes)
      #
      # @return [Integer] Unsigned long integer
      def read_unsigned_long
        read_bytes(8).unpack1("Q<")
      end
    end
  end
end
