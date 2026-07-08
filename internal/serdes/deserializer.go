package serdes

import (
	"encoding/binary"
	"fmt"
	"io"
	"math"

	"github.com/sakuro/factorix/internal/mod"
)

// Deserializer reads Factorio's binary format from a stream.
type Deserializer struct {
	r io.Reader
}

// NewDeserializer wraps r for reading.
func NewDeserializer(r io.Reader) *Deserializer {
	return &Deserializer{r: r}
}

// ReadBytes reads exactly n bytes, failing with io.ErrUnexpectedEOF (or
// io.EOF when nothing was read) on a short stream.
func (d *Deserializer) ReadBytes(n int) ([]byte, error) {
	if n < 0 {
		return nil, fmt.Errorf("%w: %d", ErrInvalidLength, n)
	}
	buf := make([]byte, n)
	if _, err := io.ReadFull(d.r, buf); err != nil {
		return nil, err
	}
	return buf, nil
}

// ReadU8 reads an unsigned 8-bit integer.
func (d *Deserializer) ReadU8() (uint8, error) {
	b, err := d.ReadBytes(1)
	if err != nil {
		return 0, err
	}
	return b[0], nil
}

// ReadU16 reads a little-endian unsigned 16-bit integer.
func (d *Deserializer) ReadU16() (uint16, error) {
	b, err := d.ReadBytes(2)
	if err != nil {
		return 0, err
	}
	return binary.LittleEndian.Uint16(b), nil
}

// ReadU32 reads a little-endian unsigned 32-bit integer.
func (d *Deserializer) ReadU32() (uint32, error) {
	b, err := d.ReadBytes(4)
	if err != nil {
		return 0, err
	}
	return binary.LittleEndian.Uint32(b), nil
}

// ReadOptimU16 reads a space-optimized 16-bit unsigned integer.
//
// See https://wiki.factorio.com/Data_types#Space_Optimized
func (d *Deserializer) ReadOptimU16() (uint16, error) {
	b, err := d.ReadU8()
	if err != nil {
		return 0, err
	}
	if b == 0xFF {
		return d.ReadU16()
	}
	return uint16(b), nil
}

// ReadOptimU32 reads a space-optimized 32-bit unsigned integer.
//
// See https://wiki.factorio.com/Data_types#Space_Optimized
func (d *Deserializer) ReadOptimU32() (uint32, error) {
	b, err := d.ReadU8()
	if err != nil {
		return 0, err
	}
	if b == 0xFF {
		return d.ReadU32()
	}
	return uint32(b), nil
}

// ReadBool reads a boolean value.
func (d *Deserializer) ReadBool() (bool, error) {
	b, err := d.ReadU8()
	if err != nil {
		return false, err
	}
	return b != 0, nil
}

// ReadStr reads a length-prefixed string.
func (d *Deserializer) ReadStr() (string, error) {
	length, err := d.ReadOptimU32()
	if err != nil {
		return "", err
	}
	b, err := d.ReadBytes(int(length))
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// ReadStrProperty reads a string preceded by an "is empty" flag.
//
// See https://wiki.factorio.com/Property_tree#String
func (d *Deserializer) ReadStrProperty() (string, error) {
	empty, err := d.ReadBool()
	if err != nil {
		return "", err
	}
	if empty {
		return "", nil
	}
	return d.ReadStr()
}

// ReadDouble reads a little-endian double-precision floating point number.
func (d *Deserializer) ReadDouble() (float64, error) {
	b, err := d.ReadBytes(8)
	if err != nil {
		return 0, err
	}
	return math.Float64frombits(binary.LittleEndian.Uint64(b)), nil
}

// ReadLong reads a little-endian signed 64-bit integer.
func (d *Deserializer) ReadLong() (int64, error) {
	v, err := d.ReadUnsignedLong()
	return int64(v), err
}

// ReadUnsignedLong reads a little-endian unsigned 64-bit integer.
func (d *Deserializer) ReadUnsignedLong() (uint64, error) {
	b, err := d.ReadBytes(8)
	if err != nil {
		return 0, err
	}
	return binary.LittleEndian.Uint64(b), nil
}

// ReadGameVersion reads a GameVersion (4 x u16).
func (d *Deserializer) ReadGameVersion() (mod.GameVersion, error) {
	var parts [4]uint16
	for i := range parts {
		v, err := d.ReadU16()
		if err != nil {
			return mod.GameVersion{}, err
		}
		parts[i] = v
	}
	return mod.GameVersion{Major: parts[0], Minor: parts[1], Patch: parts[2], Build: parts[3]}, nil
}

// ReadMODVersion reads a MODVersion (3 x optim u16).
func (d *Deserializer) ReadMODVersion() (mod.MODVersion, error) {
	var parts [3]uint16
	for i := range parts {
		v, err := d.ReadOptimU16()
		if err != nil {
			return mod.MODVersion{}, err
		}
		parts[i] = v
	}
	return mod.NewMODVersion(parts[0], parts[1], parts[2])
}

// ReadList reads a property tree list. The binary structure is identical to
// a dictionary; the per-item keys are empty and discarded.
//
// See https://wiki.factorio.com/Property_tree#List
func (d *Deserializer) ReadList() ([]PropertyTree, error) {
	count, err := d.ReadU32()
	if err != nil {
		return nil, err
	}
	var items []PropertyTree
	for range count {
		if _, err := d.ReadStrProperty(); err != nil {
			return nil, err
		}
		item, err := d.ReadPropertyTree()
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, nil
}

// ReadDictionary reads a property tree dictionary, preserving entry order.
//
// See https://wiki.factorio.com/Property_tree#Dictionary
func (d *Deserializer) ReadDictionary() ([]DictEntry, error) {
	count, err := d.ReadU32()
	if err != nil {
		return nil, err
	}
	var entries []DictEntry
	for range count {
		key, err := d.ReadStrProperty()
		if err != nil {
			return nil, err
		}
		value, err := d.ReadPropertyTree()
		if err != nil {
			return nil, err
		}
		entries = append(entries, DictEntry{Key: key, Value: value})
	}
	return entries, nil
}

// ReadPropertyTree reads one property tree element.
func (d *Deserializer) ReadPropertyTree() (PropertyTree, error) {
	typ, err := d.ReadU8()
	if err != nil {
		return PropertyTree{}, err
	}
	// The "any-type" flag is unused by Factorio; read and discard.
	if _, err := d.ReadBool(); err != nil {
		return PropertyTree{}, err
	}

	switch Kind(typ) {
	case KindNone:
		return None(), nil
	case KindBool:
		v, err := d.ReadBool()
		if err != nil {
			return PropertyTree{}, err
		}
		return Bool(v), nil
	case KindNumber:
		v, err := d.ReadDouble()
		if err != nil {
			return PropertyTree{}, err
		}
		return Number(v), nil
	case KindString:
		v, err := d.ReadStrProperty()
		if err != nil {
			return PropertyTree{}, err
		}
		return String(v), nil
	case KindList:
		items, err := d.ReadList()
		if err != nil {
			return PropertyTree{}, err
		}
		return List(items...), nil
	case KindDict:
		entries, err := d.ReadDictionary()
		if err != nil {
			return PropertyTree{}, err
		}
		return Dict(entries...), nil
	case KindSignedInt:
		v, err := d.ReadLong()
		if err != nil {
			return PropertyTree{}, err
		}
		return SignedInt(v), nil
	case KindUnsignedInt:
		v, err := d.ReadUnsignedLong()
		if err != nil {
			return PropertyTree{}, err
		}
		return UnsignedInt(v), nil
	default:
		return PropertyTree{}, &UnknownPropertyTypeError{Type: typ}
	}
}
