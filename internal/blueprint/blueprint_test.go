package blueprint

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const sampleJSON = `{"blueprint":{"item":"blueprint","label":"Test","entities":[{"entity_number":1,"name":"transport-belt"}],"version":281479275675648}}`

func TestEncodeDecodeRoundTrip(t *testing.T) {
	original, err := FromJSON([]byte(sampleJSON))
	require.NoError(t, err)

	encoded, err := original.Encode()
	require.NoError(t, err)
	assert.Equal(t, byte('0'), encoded[0])

	decoded, err := Decode(encoded)
	require.NoError(t, err)

	// Key order survives the round trip because the JSON text is kept as-is.
	reencoded, err := decoded.Encode()
	require.NoError(t, err)
	assert.Equal(t, encoded, reencoded)

	pretty, err := decoded.JSON()
	require.NoError(t, err)
	assert.Contains(t, string(pretty), `"label": "Test"`)
	assert.JSONEq(t, sampleJSON, string(pretty))
}

func TestDecodeUnsupportedVersion(t *testing.T) {
	_, err := Decode("1eJyrVspLzE1VslIqSy0qzszPU9JRKkotzi8tSk4FyRmZ6BnrKtUCAKO6DK0=")
	require.ErrorIs(t, err, ErrUnsupportedVersion)

	_, err = Decode("")
	require.ErrorIs(t, err, ErrUnsupportedVersion)
}

func TestDecodeInvalidBase64(t *testing.T) {
	_, err := Decode("0!!!not-base64!!!")
	require.ErrorIs(t, err, ErrFormat)
	assert.Contains(t, err.Error(), "Base64")
}

func TestDecodeInvalidZlib(t *testing.T) {
	// Valid Base64 of non-zlib bytes.
	_, err := Decode("0aGVsbG8gd29ybGQ=")
	require.ErrorIs(t, err, ErrFormat)
	assert.Contains(t, err.Error(), "zlib")
}

func TestFromJSONInvalid(t *testing.T) {
	_, err := FromJSON([]byte(`{"unclosed"`))
	require.ErrorIs(t, err, ErrFormat)
}
