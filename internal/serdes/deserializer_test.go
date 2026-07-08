package serdes

import (
	"bytes"
	"io"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func newDeserializer(data string) *Deserializer {
	return NewDeserializer(strings.NewReader(data))
}

func TestReadBytes(t *testing.T) {
	d := newDeserializer("\x00\x01\x02\x03\x04\x05\x06\x07")
	b, err := d.ReadBytes(5)
	require.NoError(t, err)
	assert.Equal(t, []byte{0, 1, 2, 3, 4}, b)

	b, err = d.ReadBytes(0)
	require.NoError(t, err)
	assert.Empty(t, b)

	_, err = d.ReadBytes(-1)
	require.ErrorIs(t, err, ErrInvalidLength)

	_, err = d.ReadBytes(10)
	require.ErrorIs(t, err, io.ErrUnexpectedEOF)
}

func TestReadUnsignedIntegers(t *testing.T) {
	u8, err := newDeserializer("\xaa").ReadU8()
	require.NoError(t, err)
	assert.Equal(t, uint8(0xAA), u8)

	u16, err := newDeserializer("\xaa\xbb").ReadU16()
	require.NoError(t, err)
	assert.Equal(t, uint16(0xBBAA), u16)

	u32, err := newDeserializer("\xaa\xbb\xcc\xdd").ReadU32()
	require.NoError(t, err)
	assert.Equal(t, uint32(0xDDCCBBAA), u32)

	_, err = newDeserializer("\xaa").ReadU16()
	require.ErrorIs(t, err, io.ErrUnexpectedEOF)
}

func TestReadOptimU16(t *testing.T) {
	v, err := newDeserializer("\xfe").ReadOptimU16()
	require.NoError(t, err)
	assert.Equal(t, uint16(0xFE), v)

	v, err = newDeserializer("\xff\xaa\xbb").ReadOptimU16()
	require.NoError(t, err)
	assert.Equal(t, uint16(0xBBAA), v)

	// 0xFF itself must be escaped with the sentinel.
	v, err = newDeserializer("\xff\xff\x00").ReadOptimU16()
	require.NoError(t, err)
	assert.Equal(t, uint16(0xFF), v)

	_, err = newDeserializer("\xff\xaa").ReadOptimU16()
	require.ErrorIs(t, err, io.ErrUnexpectedEOF)
}

func TestReadOptimU32(t *testing.T) {
	v, err := newDeserializer("\x99").ReadOptimU32()
	require.NoError(t, err)
	assert.Equal(t, uint32(0x99), v)

	v, err = newDeserializer("\xff\xaa\xbb\xcc\xdd").ReadOptimU32()
	require.NoError(t, err)
	assert.Equal(t, uint32(0xDDCCBBAA), v)

	_, err = newDeserializer("\xff\xaa\xbb\xcc").ReadOptimU32()
	require.ErrorIs(t, err, io.ErrUnexpectedEOF)
}

func TestReadBool(t *testing.T) {
	v, err := newDeserializer("\x00").ReadBool()
	require.NoError(t, err)
	assert.False(t, v)

	v, err = newDeserializer("\x11").ReadBool()
	require.NoError(t, err)
	assert.True(t, v)
}

func TestReadStr(t *testing.T) {
	v, err := newDeserializer("\x0chello, world").ReadStr()
	require.NoError(t, err)
	assert.Equal(t, "hello, world", v)

	long := strings.Repeat("x", 300)
	v, err = newDeserializer("\xff\x2c\x01\x00\x00" + long).ReadStr()
	require.NoError(t, err)
	assert.Equal(t, long, v)

	multibyte := "こんにちは"
	v, err = newDeserializer("\x0f" + multibyte).ReadStr()
	require.NoError(t, err)
	assert.Equal(t, multibyte, v)
}

func TestReadStrProperty(t *testing.T) {
	v, err := newDeserializer("\x01").ReadStrProperty()
	require.NoError(t, err)
	assert.Empty(t, v)

	v, err = newDeserializer("\x00\x03abc").ReadStrProperty()
	require.NoError(t, err)
	assert.Equal(t, "abc", v)
}

func TestReadDouble(t *testing.T) {
	v, err := newDeserializer("\x00\x00\x00\x00\x00\x00\xe0\x3f").ReadDouble()
	require.NoError(t, err)
	assert.InDelta(t, 0.5, v, 0)
}

func TestReadLongs(t *testing.T) {
	allFF := strings.Repeat("\xff", 8)

	sv, err := newDeserializer(allFF).ReadLong()
	require.NoError(t, err)
	assert.Equal(t, int64(-1), sv)

	uv, err := newDeserializer(allFF).ReadUnsignedLong()
	require.NoError(t, err)
	assert.Equal(t, uint64(0xFFFFFFFFFFFFFFFF), uv)
}

func TestReadGameVersion(t *testing.T) {
	v, err := newDeserializer("\x01\x00\x02\x00\x03\x00\x04\x00").ReadGameVersion()
	require.NoError(t, err)
	assert.Equal(t, mod.GameVersion{Major: 1, Minor: 2, Patch: 3, Build: 4}, v)
}

func TestReadMODVersion(t *testing.T) {
	v, err := newDeserializer("\x01\x02\x03").ReadMODVersion()
	require.NoError(t, err)
	assert.Equal(t, mod.MODVersion{Major: 1, Minor: 2, Patch: 3}, v)

	// Components over 255 are representable in optim_u16 but rejected by the
	// domain type.
	_, err = newDeserializer("\xff\x2c\x01\x00\x00").ReadMODVersion()
	var parseErr *mod.VersionParseError
	require.ErrorAs(t, err, &parseErr)
}

func TestReadDictionary(t *testing.T) {
	entries, err := newDeserializer("\x01\x00\x00\x00\x00\x05value\x02\x00\x00\x00\x00\x00\x00\x00\xe0\x3f").ReadDictionary()
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "value", entries[0].Key)
	assert.Equal(t, Number(0.5), entries[0].Value)
}

func TestReadPropertyTreeUnknownType(t *testing.T) {
	_, err := newDeserializer("\x08\x00").ReadPropertyTree()
	var unknownErr *UnknownPropertyTypeError
	require.ErrorAs(t, err, &unknownErr)
	assert.Equal(t, uint8(8), unknownErr.Type)
}

func TestReadPropertyTreeTruncated(t *testing.T) {
	_, err := newDeserializer("\x01\x00\x00\x00\x00\x05value\x02\x00\x00\x00\x00\x00\x00\x00\xe0").ReadDictionary()
	require.ErrorIs(t, err, io.ErrUnexpectedEOF)
}

func TestPropertyTreeRoundTrip(t *testing.T) {
	tree := Dict(
		DictEntry{Key: "none", Value: None()},
		DictEntry{Key: "bool", Value: Bool(true)},
		DictEntry{Key: "number", Value: Number(0.5)},
		DictEntry{Key: "string", Value: String("hello")},
		DictEntry{Key: "empty-string", Value: String("")},
		DictEntry{Key: "list", Value: List(Number(1), String("two"), Bool(false))},
		DictEntry{Key: "dict", Value: Dict(DictEntry{Key: "nested", Value: Number(2)})},
		DictEntry{Key: "signed", Value: SignedInt(-42)},
		DictEntry{Key: "unsigned", Value: UnsignedInt(42)},
	)

	var buf bytes.Buffer
	require.NoError(t, NewSerializer(&buf).WritePropertyTree(tree))
	first := buf.Bytes()

	got, err := NewDeserializer(bytes.NewReader(first)).ReadPropertyTree()
	require.NoError(t, err)
	assert.Equal(t, tree, got)

	// Serializing the reread tree must be byte-identical.
	var buf2 bytes.Buffer
	require.NoError(t, NewSerializer(&buf2).WritePropertyTree(got))
	assert.Equal(t, first, buf2.Bytes())
}
