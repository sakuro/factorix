#!/usr/bin/env ruby
# frozen_string_literal: true

require "chunky_png"

# Create a 144x144 PNG with gray color #999999
image = ChunkyPNG::Image.new(144, 144, ChunkyPNG::Color.rgb(153, 153, 153))
image.save("thumbnail.png")

puts "Created thumbnail.png (144x144, #999999)"