# frozen_string_literal: true

module Factorix
  # Serialize data to binary format
  class Serializer
    # Create a new Serializer instance
    #
    # @param stream [IO] An IO-like object that responds to #write
    # @raise [ArgumentError] If the stream doesn't respond to #write
    def initialize(stream)
      raise ArgumentError, "can't read from the given argument" unless stream.respond_to?(:write)

      @stream = stream
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
    # https://wiki.factorio.com/Data_types#Space_Optimized
    #
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
    # https://wiki.factorio.com/Data_types#Space_Optimized
    #
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
    # @param str [String] String to write
    # @return [void]
    def write_str(str)
      write_optim_u32(str.length)
      write_bytes(str.b)
    end

    # Write a string property
    # https://wiki.factorio.com/Property_tree#String
    #
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
    # https://wiki.factorio.com/Property_tree#Number
    #
    # @param dbl [Float] Double-precision floating point number
    # @return [void]
    def write_double(dbl) = write_bytes([dbl].pack("d"))

    # Write a Version64 object
    #
    # @param v64 [Version64] Version64 object
    # @return [void]
    def write_version64(v64) = v64.to_a.each {|u16| write_u16(u16) }

    # Write a Version24 object
    #
    # @param v24 [Version24] Version24 object
    # @return [void]
    def write_version24(v24) = v24.to_a.each {|u16| write_optim_u16(u16) }

    # Write a list
    # https://wiki.factorio.com/Property_tree#List
    #
    # @param list [Array] List of objects
    # @return [void]
    def write_list(list)
      write_optim_u32(list.size)
      list.each {|e| write_property_tree(e) }
    end

    # Write a dictionary
    # https://wiki.factorio.com/Property_tree#Dictionary
    #
    # @param dict [Hash] Dictionary of key-value pairs
    # @return [void]
    def write_dictionary(dict)
      write_u32(dict.size)
      dict.each do |(key, value)|
        write_str_property(key)
        write_property_tree(value)
      end
    end

    # Write a property tree
    #
    # @param obj [Object] Object to write
    # @raise [UnknownPropertyType] If the object type is not supported
    # @return [void]
    def write_property_tree(obj)
      case obj
      in true | false => bool
        write_u8(1)
        write_bool(false)
        write_bool(bool)
      in Float => dbl
        write_u8(2)
        write_bool(false)
        write_double(dbl)
      in String => str
        case str
        when /\Argba:(?<r>\h{2})(?<g>\h{2})(?<b>\h{2})(?<a>\h{2})\z/
          # convert "rgba:RRGGBBAA" to {"r": RR, "g": GG, "b": BB, "a": AA }"
          write_u8(5)
          write_bool(false)
          write_dictionary(%w[r g b a].each_with_object({}) {|k, dict| dict[k] = $~[k].to_i(16) / 255.0 })
        else
          write_u8(3)
          write_bool(false)
          write_str_property(str)
        end
      in Array => list
        write_u8(4)
        write_bool(false)
        write_list(list)
      in Hash => dict
        write_u8(5)
        write_bool(false)
        write_dictionary(dict)
      else
        raise Factorix::UnknownPropertyType, obj.class
      end
    end
  end
end
