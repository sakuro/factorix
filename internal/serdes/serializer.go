package serdes

import (
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"unicode/utf8"

	"github.com/sakuro/factorix/internal/mod"
)

// Serializer writes Factorio's binary format to a stream.
type Serializer struct {
	w io.Writer
}

// NewSerializer wraps w for writing.
func NewSerializer(w io.Writer) *Serializer {
	return &Serializer{w: w}
}

// WriteBytes writes raw bytes.
func (s *Serializer) WriteBytes(p []byte) error {
	_, err := s.w.Write(p)
	return err
}

// WriteU8 writes an unsigned 8-bit integer.
func (s *Serializer) WriteU8(v uint8) error {
	return s.WriteBytes([]byte{v})
}

// WriteU16 writes a little-endian unsigned 16-bit integer.
func (s *Serializer) WriteU16(v uint16) error {
	return s.WriteBytes(binary.LittleEndian.AppendUint16(nil, v))
}

// WriteU32 writes a little-endian unsigned 32-bit integer.
func (s *Serializer) WriteU32(v uint32) error {
	return s.WriteBytes(binary.LittleEndian.AppendUint32(nil, v))
}

// WriteOptimU16 writes a space-optimized 16-bit unsigned integer.
//
// See https://wiki.factorio.com/Data_types#Space_Optimized
func (s *Serializer) WriteOptimU16(v uint16) error {
	if v < 0xFF {
		return s.WriteU8(uint8(v))
	}
	if err := s.WriteU8(0xFF); err != nil {
		return err
	}
	return s.WriteU16(v)
}

// WriteOptimU32 writes a space-optimized 32-bit unsigned integer.
//
// See https://wiki.factorio.com/Data_types#Space_Optimized
func (s *Serializer) WriteOptimU32(v uint32) error {
	if v < 0xFF {
		return s.WriteU8(uint8(v))
	}
	if err := s.WriteU8(0xFF); err != nil {
		return err
	}
	return s.WriteU32(v)
}

// WriteBool writes a boolean value.
func (s *Serializer) WriteBool(v bool) error {
	if v {
		return s.WriteU8(0x01)
	}
	return s.WriteU8(0x00)
}

// WriteStr writes a length-prefixed string. The string must be valid UTF-8.
func (s *Serializer) WriteStr(str string) error {
	if !utf8.ValidString(str) {
		return fmt.Errorf("%w: %q", ErrInvalidUTF8, str)
	}
	if err := s.WriteOptimU32(uint32(len(str))); err != nil {
		return err
	}
	return s.WriteBytes([]byte(str))
}

// WriteStrProperty writes a string preceded by an "is empty" flag.
//
// See https://wiki.factorio.com/Property_tree#String
func (s *Serializer) WriteStrProperty(str string) error {
	if str == "" {
		return s.WriteBool(true)
	}
	if err := s.WriteBool(false); err != nil {
		return err
	}
	return s.WriteStr(str)
}

// WriteDouble writes a little-endian double-precision floating point number.
func (s *Serializer) WriteDouble(v float64) error {
	return s.WriteBytes(binary.LittleEndian.AppendUint64(nil, math.Float64bits(v)))
}

// WriteLong writes a little-endian signed 64-bit integer.
func (s *Serializer) WriteLong(v int64) error {
	return s.WriteUnsignedLong(uint64(v))
}

// WriteUnsignedLong writes a little-endian unsigned 64-bit integer.
func (s *Serializer) WriteUnsignedLong(v uint64) error {
	return s.WriteBytes(binary.LittleEndian.AppendUint64(nil, v))
}

// WriteGameVersion writes a GameVersion (4 x u16).
func (s *Serializer) WriteGameVersion(v mod.GameVersion) error {
	for _, u := range [...]uint16{v.Major, v.Minor, v.Patch, v.Build} {
		if err := s.WriteU16(u); err != nil {
			return err
		}
	}
	return nil
}

// WriteMODVersion writes a MODVersion (3 x optim u16).
func (s *Serializer) WriteMODVersion(v mod.MODVersion) error {
	for _, u := range [...]uint16{v.Major, v.Minor, v.Patch} {
		if err := s.WriteOptimU16(u); err != nil {
			return err
		}
	}
	return nil
}

// List and Dictionary share one binary layout — both serialize a Lua table:
// u32 count, then a string key and a nested tree per entry. Lists carry
// empty keys.
func (s *Serializer) writeEntries(entries []DictEntry) error {
	if err := s.WriteU32(uint32(len(entries))); err != nil {
		return err
	}
	for _, entry := range entries {
		if err := s.WriteStrProperty(entry.Key); err != nil {
			return err
		}
		if err := s.WritePropertyTree(entry.Value); err != nil {
			return err
		}
	}
	return nil
}

// WriteList writes a property tree list, giving each item an empty key.
//
// See https://wiki.factorio.com/Property_tree#List
func (s *Serializer) WriteList(items []PropertyTree) error {
	entries := make([]DictEntry, len(items))
	for i, item := range items {
		entries[i] = DictEntry{Value: item}
	}
	return s.writeEntries(entries)
}

// WriteDictionary writes a property tree dictionary in entry order.
//
// See https://wiki.factorio.com/Property_tree#Dictionary
func (s *Serializer) WriteDictionary(entries []DictEntry) error {
	return s.writeEntries(entries)
}

// WritePropertyTree writes one property tree element.
func (s *Serializer) WritePropertyTree(pt PropertyTree) error {
	if err := s.WriteU8(uint8(pt.Kind)); err != nil {
		return err
	}
	// The "any-type" flag is unused by Factorio; always written as false.
	if err := s.WriteBool(false); err != nil {
		return err
	}

	switch pt.Kind {
	case KindNone:
		return nil
	case KindBool:
		v, ok := pt.Bool()
		if !ok {
			return valueMismatch(pt)
		}
		return s.WriteBool(v)
	case KindNumber:
		v, ok := pt.Number()
		if !ok {
			return valueMismatch(pt)
		}
		return s.WriteDouble(v)
	case KindString:
		v, ok := pt.Str()
		if !ok {
			return valueMismatch(pt)
		}
		return s.WriteStrProperty(v)
	case KindList:
		v, ok := pt.List()
		if !ok {
			return valueMismatch(pt)
		}
		return s.WriteList(v)
	case KindDict:
		v, ok := pt.Dict()
		if !ok {
			return valueMismatch(pt)
		}
		return s.WriteDictionary(v)
	case KindSignedInt:
		v, ok := pt.SignedInt()
		if !ok {
			return valueMismatch(pt)
		}
		return s.WriteLong(v)
	case KindUnsignedInt:
		v, ok := pt.UnsignedInt()
		if !ok {
			return valueMismatch(pt)
		}
		return s.WriteUnsignedLong(v)
	default:
		return &UnknownPropertyTypeError{Type: uint8(pt.Kind)}
	}
}

func valueMismatch(pt PropertyTree) error {
	return fmt.Errorf("property tree kind %v holds %T", pt.Kind, pt.Value)
}
