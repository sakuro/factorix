package serdes

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func serialize(t *testing.T, write func(*Serializer) error) []byte {
	t.Helper()
	var buf bytes.Buffer
	require.NoError(t, write(NewSerializer(&buf)))
	return buf.Bytes()
}

func TestWriteUnsignedIntegers(t *testing.T) {
	assert.Equal(t, []byte{0xAA}, serialize(t, func(s *Serializer) error { return s.WriteU8(0xAA) }))
	assert.Equal(t, []byte{0xAA, 0xBB}, serialize(t, func(s *Serializer) error { return s.WriteU16(0xBBAA) }))
	assert.Equal(t, []byte{0xAA, 0xBB, 0xCC, 0xDD}, serialize(t, func(s *Serializer) error { return s.WriteU32(0xDDCCBBAA) }))
}

func TestWriteOptimU16(t *testing.T) {
	assert.Equal(t, []byte{0xFE}, serialize(t, func(s *Serializer) error { return s.WriteOptimU16(0xFE) }))
	// 0xFF itself must be escaped with the sentinel.
	assert.Equal(t, []byte{0xFF, 0xFF, 0x00}, serialize(t, func(s *Serializer) error { return s.WriteOptimU16(0xFF) }))
	assert.Equal(t, []byte{0xFF, 0xAA, 0xBB}, serialize(t, func(s *Serializer) error { return s.WriteOptimU16(0xBBAA) }))
}

func TestWriteOptimU32(t *testing.T) {
	assert.Equal(t, []byte{0x99}, serialize(t, func(s *Serializer) error { return s.WriteOptimU32(0x99) }))
	assert.Equal(t, []byte{0xFF, 0xAA, 0xBB, 0xCC, 0xDD}, serialize(t, func(s *Serializer) error { return s.WriteOptimU32(0xDDCCBBAA) }))
}

func TestWriteBool(t *testing.T) {
	assert.Equal(t, []byte{0x01}, serialize(t, func(s *Serializer) error { return s.WriteBool(true) }))
	assert.Equal(t, []byte{0x00}, serialize(t, func(s *Serializer) error { return s.WriteBool(false) }))
}

func TestWriteStr(t *testing.T) {
	assert.Equal(t, []byte("\x0chello, world"), serialize(t, func(s *Serializer) error { return s.WriteStr("hello, world") }))

	var buf bytes.Buffer
	err := NewSerializer(&buf).WriteStr(string([]byte{0xFF, 0xFE}))
	require.ErrorIs(t, err, ErrInvalidUTF8)
}

func TestWriteStrProperty(t *testing.T) {
	assert.Equal(t, []byte{0x01}, serialize(t, func(s *Serializer) error { return s.WriteStrProperty("") }))
	assert.Equal(t, []byte("\x00\x03abc"), serialize(t, func(s *Serializer) error { return s.WriteStrProperty("abc") }))
}

func TestWriteDouble(t *testing.T) {
	assert.Equal(t, []byte{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE0, 0x3F}, serialize(t, func(s *Serializer) error { return s.WriteDouble(0.5) }))
}

func TestWriteLongs(t *testing.T) {
	allFF := bytes.Repeat([]byte{0xFF}, 8)
	assert.Equal(t, allFF, serialize(t, func(s *Serializer) error { return s.WriteLong(-1) }))
	assert.Equal(t, allFF, serialize(t, func(s *Serializer) error { return s.WriteUnsignedLong(0xFFFFFFFFFFFFFFFF) }))
}

func TestWriteGameVersion(t *testing.T) {
	v := mod.GameVersion{Major: 1, Minor: 2, Patch: 3, Build: 4}
	assert.Equal(t, []byte{0x01, 0x00, 0x02, 0x00, 0x03, 0x00, 0x04, 0x00}, serialize(t, func(s *Serializer) error { return s.WriteGameVersion(v) }))
}

func TestWriteMODVersion(t *testing.T) {
	v := mod.MODVersion{Major: 1, Minor: 2, Patch: 255}
	assert.Equal(t, []byte{0x01, 0x02, 0xFF, 0xFF, 0x00}, serialize(t, func(s *Serializer) error { return s.WriteMODVersion(v) }))
}

func TestWriteDictionary(t *testing.T) {
	entries := []DictEntry{{Key: "value", Value: Number(0.5)}}
	assert.Equal(t,
		[]byte("\x01\x00\x00\x00\x00\x05value\x02\x00\x00\x00\x00\x00\x00\x00\xe0\x3f"),
		serialize(t, func(s *Serializer) error { return s.WriteDictionary(entries) }),
	)
}

func TestWriteList(t *testing.T) {
	// Same structure as a dictionary: u32 count, then empty key + tree per item.
	assert.Equal(t,
		[]byte("\x01\x00\x00\x00\x01\x01\x00\x01"),
		serialize(t, func(s *Serializer) error { return s.WriteList([]PropertyTree{Bool(true)}) }),
	)
}

func TestWritePropertyTreeValueMismatch(t *testing.T) {
	var buf bytes.Buffer
	err := NewSerializer(&buf).WritePropertyTree(PropertyTree{Kind: KindBool, Value: "not a bool"})
	require.Error(t, err)
}

func TestWritePropertyTreeUnknownKind(t *testing.T) {
	var buf bytes.Buffer
	err := NewSerializer(&buf).WritePropertyTree(PropertyTree{Kind: Kind(8)})
	var unknownErr *UnknownPropertyTypeError
	require.ErrorAs(t, err, &unknownErr)
}
