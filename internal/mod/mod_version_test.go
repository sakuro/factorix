package mod

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseMODVersion(t *testing.T) {
	tests := []struct {
		input string
		want  MODVersion
	}{
		{"1.2.3", MODVersion{Major: 1, Minor: 2, Patch: 3}},
		{"1.2", MODVersion{Major: 1, Minor: 2}},
		{"0.0.0", MODVersion{}},
		{"65535.65535.65535", MODVersion{Major: 65535, Minor: 65535, Patch: 65535}},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got, err := ParseMODVersion(tt.input)
			require.NoError(t, err)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestParseMODVersionInvalid(t *testing.T) {
	inputs := []string{"", "1", "1.2.3.4", "a.b.c", "1.2.3-4", " 1.2.3", "65536.0.0"}
	for _, input := range inputs {
		t.Run(input, func(t *testing.T) {
			_, err := ParseMODVersion(input)
			var parseErr *VersionParseError
			require.ErrorAs(t, err, &parseErr)
		})
	}
}

func TestMODVersionString(t *testing.T) {
	assert.Equal(t, "1.2.3", MODVersion{Major: 1, Minor: 2, Patch: 3}.String())
	assert.Equal(t, "1.2.0", MODVersion{Major: 1, Minor: 2}.String())
}

func TestMODVersionCompare(t *testing.T) {
	base := MODVersion{Major: 1, Minor: 2, Patch: 3}
	assert.Equal(t, 0, base.Compare(MODVersion{Major: 1, Minor: 2, Patch: 3}))
	assert.Equal(t, -1, base.Compare(MODVersion{Major: 1, Minor: 3, Patch: 0}))
	assert.Equal(t, 1, base.Compare(MODVersion{Major: 1, Minor: 2, Patch: 2}))
	assert.True(t, base.Less(MODVersion{Major: 2}))
	assert.False(t, base.Less(base))
}
