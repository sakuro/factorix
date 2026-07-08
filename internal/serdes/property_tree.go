// Package serdes reads and writes Factorio's custom binary format used in
// save files and mod-settings.dat.
//
// See https://wiki.factorio.com/Property_tree
package serdes

import "fmt"

// Kind identifies the runtime type of a PropertyTree value. The numeric
// values match the type bytes in the binary format.
type Kind uint8

const (
	KindNone Kind = iota
	KindBool
	KindNumber
	KindString
	KindList
	KindDict
	KindSignedInt
	KindUnsignedInt
)

func (k Kind) String() string {
	switch k {
	case KindNone:
		return "none"
	case KindBool:
		return "bool"
	case KindNumber:
		return "number"
	case KindString:
		return "string"
	case KindList:
		return "list"
	case KindDict:
		return "dict"
	case KindSignedInt:
		return "signed-int"
	case KindUnsignedInt:
		return "unsigned-int"
	default:
		return fmt.Sprintf("Kind(%d)", uint8(k))
	}
}

// PropertyTree is Factorio's recursive tagged union. Value holds
// nil / bool / float64 / string / []PropertyTree / []DictEntry / int64 /
// uint64 depending on Kind; use the kind-checked accessors instead of
// asserting on Value directly.
type PropertyTree struct {
	Kind  Kind
	Value any
}

// DictEntry is one key-value pair of a dictionary. Entries are a slice, not
// a map, so that a load-and-save round trip preserves file order byte for
// byte.
type DictEntry struct {
	Key   string
	Value PropertyTree
}

// None returns a PropertyTree of the None type.
func None() PropertyTree {
	return PropertyTree{Kind: KindNone}
}

// Bool returns a PropertyTree wrapping a boolean.
func Bool(v bool) PropertyTree {
	return PropertyTree{Kind: KindBool, Value: v}
}

// Number returns a PropertyTree wrapping a double.
func Number(v float64) PropertyTree {
	return PropertyTree{Kind: KindNumber, Value: v}
}

// String returns a PropertyTree wrapping a string.
func String(v string) PropertyTree {
	return PropertyTree{Kind: KindString, Value: v}
}

// List returns a PropertyTree wrapping a list.
func List(items ...PropertyTree) PropertyTree {
	return PropertyTree{Kind: KindList, Value: items}
}

// Dict returns a PropertyTree wrapping a dictionary.
func Dict(entries ...DictEntry) PropertyTree {
	return PropertyTree{Kind: KindDict, Value: entries}
}

// SignedInt returns a PropertyTree wrapping a signed 64-bit integer.
func SignedInt(v int64) PropertyTree {
	return PropertyTree{Kind: KindSignedInt, Value: v}
}

// UnsignedInt returns a PropertyTree wrapping an unsigned 64-bit integer.
func UnsignedInt(v uint64) PropertyTree {
	return PropertyTree{Kind: KindUnsignedInt, Value: v}
}

// Bool returns the boolean value; ok is false when the kind differs.
func (pt PropertyTree) Bool() (v, ok bool) {
	if pt.Kind != KindBool {
		return false, false
	}
	v, ok = pt.Value.(bool)
	return v, ok
}

// Number returns the double value; ok is false when the kind differs.
func (pt PropertyTree) Number() (float64, bool) {
	if pt.Kind != KindNumber {
		return 0, false
	}
	v, ok := pt.Value.(float64)
	return v, ok
}

// Str returns the string value; ok is false when the kind differs.
// (Not named String to avoid colliding with fmt.Stringer.)
func (pt PropertyTree) Str() (string, bool) {
	if pt.Kind != KindString {
		return "", false
	}
	v, ok := pt.Value.(string)
	return v, ok
}

// List returns the list items; ok is false when the kind differs.
func (pt PropertyTree) List() ([]PropertyTree, bool) {
	if pt.Kind != KindList {
		return nil, false
	}
	v, ok := pt.Value.([]PropertyTree)
	return v, ok
}

// Dict returns the dictionary entries; ok is false when the kind differs.
func (pt PropertyTree) Dict() ([]DictEntry, bool) {
	if pt.Kind != KindDict {
		return nil, false
	}
	v, ok := pt.Value.([]DictEntry)
	return v, ok
}

// SignedInt returns the signed integer value; ok is false when the kind differs.
func (pt PropertyTree) SignedInt() (int64, bool) {
	if pt.Kind != KindSignedInt {
		return 0, false
	}
	v, ok := pt.Value.(int64)
	return v, ok
}

// UnsignedInt returns the unsigned integer value; ok is false when the kind differs.
func (pt PropertyTree) UnsignedInt() (uint64, bool) {
	if pt.Kind != KindUnsignedInt {
		return 0, false
	}
	v, ok := pt.Value.(uint64)
	return v, ok
}
