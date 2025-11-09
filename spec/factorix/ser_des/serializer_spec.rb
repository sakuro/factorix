# frozen_string_literal: true

require "stringio"

RSpec.describe Factorix::SerDes::Serializer do
  let(:serializer) { Factorix::SerDes::Serializer.new(stream) }
  let(:stream) { StringIO.new("".b) }

  describe ".new" do
    context "with object without #write" do
      it "raises ArgumentError if the argument does not respond to #write" do
        expect { Factorix::SerDes::Serializer.new(%w[x y z]) }.to raise_error(ArgumentError)
      end
    end

    it "instantiates with an input stream" do
      expect(Factorix::SerDes::Serializer.new(StringIO.new("".b))).to be_an_instance_of(Factorix::SerDes::Serializer)
    end
  end

  describe "#write_bytes" do
    let(:binary_data) { "\x00\x01\x02\x03\x04\x05\x06\x07".b }

    it "writes given data" do
      expect { serializer.write_bytes(binary_data) }.to change(stream, :string).from("".b).to("\x00\x01\x02\x03\x04\x05\x06\x07".b)
    end

    context "with zero length" do
      it "writes nothing" do
        expect { serializer.write_bytes("") }.not_to change(stream, :string).from("".b)
      end
    end

    context "with nil" do
      it "raises ArgumentError" do
        expect { serializer.write_bytes(nil) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#write_u8" do
    it "writes given value" do
      expect { serializer.write_u8(23) }.to change(stream, :string).from("".b).to("\x17".b)
    end
  end

  describe "#write_u16" do
    it "writes given value" do
      expect { serializer.write_u16(2023) }.to change(stream, :string).from("".b).to("\xE7\x07".b)
    end
  end

  describe "#write_u32" do
    it "writes given value" do
      expect { serializer.write_u32(20_230_128) }.to change(stream, :string).from("".b).to("\xF0\xAF\x34\x01".b)
    end
  end

  describe "#write_optim_u16" do
    context "when value < 0xFF" do
      it "writes value as a byte" do
        expect { serializer.write_optim_u16(23) }.to change(stream, :string).from("".b).to("\x17".b)
      end

      it "writes 254 (0xFE) as a single byte" do
        expect { serializer.write_optim_u16(254) }.to change(stream, :string).from("".b).to("\xFE".b)
      end
    end

    context "when value >= 0xFF" do
      it "writes 0xFF and value for 255" do
        expect { serializer.write_optim_u16(255) }.to change(stream, :string).from("".b).to("\xFF\xFF\x00".b)
      end

      it "writes 0xFF and value for larger values" do
        expect { serializer.write_optim_u16(2023) }.to change(stream, :string).from("".b).to("\xFF\xE7\x07".b)
      end
    end
  end

  describe "#write_optim_u32" do
    context "when value < 0xFF" do
      it "writes value as a byte" do
        expect { serializer.write_optim_u32(23) }.to change(stream, :string).from("".b).to("\x17".b)
      end

      it "writes 254 (0xFE) as a single byte" do
        expect { serializer.write_optim_u32(254) }.to change(stream, :string).from("".b).to("\xFE".b)
      end
    end

    context "when value >= 0xFF" do
      it "writes 0xFF and value for 255" do
        expect { serializer.write_optim_u32(255) }.to change(stream, :string).from("".b).to("\xFF\xFF\x00\x00\x00".b)
      end

      it "writes 0xFF and value for larger values" do
        expect { serializer.write_optim_u32(20_230_128) }.to change(stream, :string).from("".b).to("\xFF\xF0\xAF\x34\x01".b)
      end
    end
  end

  describe "#write_bool" do
    it "writes false as 0x00" do
      expect { serializer.write_bool(false) }.to change(stream, :string).from("".b).to("\x00".b)
    end

    it "writes true as 0x01" do
      expect { serializer.write_bool(true) }.to change(stream, :string).from("".b).to("\x01".b)
    end
  end

  describe "#write_str" do
    context "when writing string with bytesize < 0xFF" do
      it "writes bytesize as a byte followed by string data" do
        expect { serializer.write_str("hello, world") }.to change(stream, :string).from("".b).to("\x0Chello, world".b)
      end

      it "writes UTF-8 multibyte string with correct bytesize" do
        # "こんにちは" is 15 bytes in UTF-8 (5 characters × 3 bytes each)
        expect { serializer.write_str("こんにちは") }.to change(stream, :string).from("".b).to("\x0F#{"\u3053\u3093\u306B\u3061\u306F".encode(Encoding::UTF_8)}".b)
      end
    end

    context "when writing string with bytesize >= 0xFF" do
      it "writes 0xFF, bytesize as a u32 followed by string data" do
        expect { serializer.write_str("x" * 300) }.to change(stream, :string).from("".b).to("\xFF\x2C\x01\x00\x00#{"x" * 300}".b)
      end

      it "writes long UTF-8 multibyte string with correct bytesize" do
        # "あ" is 3 bytes in UTF-8, so 100 characters = 300 bytes
        long_str = "あ" * 100
        expected = "\xFF\x2C\x01\x00\x00#{long_str}".b
        expect { serializer.write_str(long_str) }.to change(stream, :string).from("".b).to(expected)
      end
    end

    context "with non-UTF-8 encoded string" do
      it "raises ArgumentError for Shift_JIS encoded string" do
        sjis_str = "こんにちは".encode(Encoding::Shift_JIS)
        expect { serializer.write_str(sjis_str) }.to raise_error(ArgumentError, /must be UTF-8 encoded/)
      end
    end
  end

  describe "#write_str_property" do
    context "when writing empty string" do
      it "writes only no string flag as true" do
        expect { serializer.write_str_property("") }.to change(stream, :string).from("".b).to("\x01".b)
      end
    end

    context "when writing non empty string" do
      it "writes no string flag asf false, length and data" do
        expect { serializer.write_str_property("hello, world") }.to change(stream, :string).from("".b).to("\x00\x0chello, world".b)
      end
    end
  end

  describe "#write_double" do
    it "writes value" do
      expect { serializer.write_double(1.999969482421875) }.to change(stream, :string).from("".b).to("\x00\x00\x00\x00\xe0\xff\xff\x3f".b)
    end
  end

  describe "#write_game_version" do
    it "writes GameVersion" do
      expect { serializer.write_game_version(Factorix::Types::GameVersion.from_numbers(1, 2, 3, 4)) }.to change(stream, :string).from("".b).to("\x01\x00\x02\x00\x03\x00\x04\x00".b)
    end
  end

  describe "#write_mod_version" do
    it "writes MODVersion" do
      expect { serializer.write_mod_version(Factorix::Types::MODVersion.from_numbers(1, 2, 3)) }.to change(stream, :string).from("".b).to("\x01\x02\x03".b)
    end
  end

  describe "#write_long" do
    it "writes signed long integer" do
      expect { serializer.write_long(-1) }.to change(stream, :string).from("".b).to("\xff\xff\xff\xff\xff\xff\xff\xff".b)
    end
  end

  describe "#write_unsigned_long" do
    it "writes unsigned long integer" do
      expect { serializer.write_unsigned_long(0xFFFFFFFFFFFFFFFF) }.to change(stream, :string).from("".b).to("\xff\xff\xff\xff\xff\xff\xff\xff".b)
    end
  end

  describe "#write_list" do
    it "writes list of property trees" do
      # Expected binary data:
      # - List length: 2 (\x02)
      # - First element: type 2 (double) with value 0.5
      # - Second element: type 2 (double) with value 2.0

      # Mock the write_property_tree method to avoid actual serialization
      allow(serializer).to receive(:write_optim_u32)
      allow(serializer).to receive(:write_property_tree)

      serializer.write_list([0.5, 2.0])

      aggregate_failures "writing list" do
        expect(serializer).to have_received(:write_optim_u32).with(2).ordered
        expect(serializer).to have_received(:write_property_tree).with(0.5).ordered
        expect(serializer).to have_received(:write_property_tree).with(2.0).ordered
      end
    end

    context "with empty list" do
      it "writes only the length (0)" do
        expect { serializer.write_list([]) }.to change(stream, :string).from("".b).to("\x00")
      end
    end

    context "with mixed types" do
      it "writes each element with its appropriate type" do
        # Mock the write_property_tree method to avoid actual serialization
        allow(serializer).to receive(:write_optim_u32)
        allow(serializer).to receive(:write_property_tree)

        serializer.write_list([true, 0.5, "test"])

        aggregate_failures "writing mixed types" do
          expect(serializer).to have_received(:write_optim_u32).with(3).ordered
          expect(serializer).to have_received(:write_property_tree).with(true).ordered
          expect(serializer).to have_received(:write_property_tree).with(0.5).ordered
          expect(serializer).to have_received(:write_property_tree).with("test").ordered
        end
      end
    end
  end

  describe "#write_dictionary" do
    it "writes dictionary" do
      expect { serializer.write_dictionary("value" => 0.5) }.to change(stream, :string).from("".b).to("\x01\x00\x00\x00\x00\x05value\x02\x00\x00\x00\x00\x00\x00\x00\xE0\x3F".b)
    end
  end

  describe "#write_property_tree" do
    before do
      allow(serializer).to receive(:write_u8)
      allow(serializer).to receive(:write_bool).with(false)
    end

    context "when writing bool" do
      before do
        allow(serializer).to receive(:write_bool).with(true)
      end

      it "calls write_bool" do
        serializer.write_property_tree(true)

        aggregate_failures "writing bool" do
          expect(serializer).to have_received(:write_u8).with(1).ordered
          expect(serializer).to have_received(:write_bool).with(false).ordered
          expect(serializer).to have_received(:write_bool).with(true).ordered
        end
      end
    end

    context "when writing number" do
      before do
        allow(serializer).to receive(:write_double)
      end

      it "calls write_double" do
        serializer.write_property_tree(0.5)

        aggregate_failures "writing number" do
          expect(serializer).to have_received(:write_u8).with(2).ordered
          expect(serializer).to have_received(:write_bool).with(false).ordered
          expect(serializer).to have_received(:write_double).with(0.5).ordered
        end
      end
    end

    context "when writing string" do
      before do
        allow(serializer).to receive(:write_str_property)
      end

      it "calls write_str_property" do
        serializer.write_property_tree("value")

        aggregate_failures "writing string" do
          expect(serializer).to have_received(:write_u8).with(3).ordered
          expect(serializer).to have_received(:write_bool).with(false).ordered
          expect(serializer).to have_received(:write_str_property).with("value").ordered
        end
      end
    end

    context "when writing list" do
      before do
        allow(serializer).to receive(:write_list)
      end

      it "calls write_list" do
        serializer.write_property_tree([1.0, 2.0])

        aggregate_failures "writing list" do
          expect(serializer).to have_received(:write_u8).with(4).ordered
          expect(serializer).to have_received(:write_bool).with(false).ordered
          expect(serializer).to have_received(:write_list).with([1.0, 2.0]).ordered
        end
      end
    end

    context "when writing dictionary" do
      before do
        allow(serializer).to receive(:write_dictionary)
      end

      it "calls write_dictionary" do
        serializer.write_property_tree("value" => 0.5)

        aggregate_failures "writing dictionary" do
          expect(serializer).to have_received(:write_u8).with(5).ordered
          expect(serializer).to have_received(:write_bool).with(false).ordered
          expect(serializer).to have_received(:write_dictionary).with("value" => 0.5).ordered
        end
      end
    end

    context "when writing unknown object type" do
      it "raises Factorix::UnknownPropertyType" do
        expect { serializer.write_property_tree(Object.new) }.to raise_error(Factorix::UnknownPropertyType)
      end
    end
  end
end
