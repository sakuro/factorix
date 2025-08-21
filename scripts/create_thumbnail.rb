#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

# Simple PNG header and data for a 144x144 gray image
# This creates a minimal PNG file without external dependencies
def create_simple_png
  # PNG header
  png_signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*")
  
  # IHDR chunk
  width = 144
  height = 144
  bit_depth = 8
  color_type = 2  # RGB
  compression = 0
  filter = 0
  interlace = 0
  
  ihdr_data = [width, height, bit_depth, color_type, compression, filter, interlace].pack("N2C5")
  ihdr_crc = Zlib.crc32(["IHDR", ihdr_data].join)
  ihdr_chunk = [ihdr_data.length, "IHDR", ihdr_data, ihdr_crc].pack("NA4A*N")
  
  # Create gray pixel data (RGB: 153, 153, 153 = #999999)
  row_data = ([0] + [153, 153, 153] * width).pack("C*")  # Filter byte + RGB pixels
  idat_raw = row_data * height
  idat_compressed = Zlib.deflate(idat_raw)
  idat_crc = Zlib.crc32(["IDAT", idat_compressed].join)
  idat_chunk = [idat_compressed.length, "IDAT", idat_compressed, idat_crc].pack("NA4A*N")
  
  # IEND chunk
  iend_crc = Zlib.crc32("IEND")
  iend_chunk = [0, "IEND", iend_crc].pack("NA4N")
  
  png_signature + ihdr_chunk + idat_chunk + iend_chunk
end

# Create the data directory
FileUtils.mkdir_p("data")

# Write the PNG file
File.binwrite("data/thumbnail.png", create_simple_png)
puts "Created data/thumbnail.png (144x144, #999999)"