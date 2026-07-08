package mod

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseGameVersion(t *testing.T) {
	tests := []struct {
		input string
		want  GameVersion
	}{
		{"1.2.3", GameVersion{Major: 1, Minor: 2, Patch: 3}},
		{"1.2.3-4", GameVersion{Major: 1, Minor: 2, Patch: 3, Build: 4}},
		{"2.0.28-1", GameVersion{Major: 2, Minor: 0, Patch: 28, Build: 1}},
		{"0.0.0", GameVersion{}},
		{"65535.65535.65535-65535", GameVersion{Major: 65535, Minor: 65535, Patch: 65535, Build: 65535}},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got, err := ParseGameVersion(tt.input)
			require.NoError(t, err)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestParseGameVersionInvalid(t *testing.T) {
	inputs := []string{"", "1.2", "1.2.3.4", "a.b.c", "1.2.3-", "-1.2.3", "1.2.3 ", "65536.0.0", "1.2.3-65536"}
	for _, input := range inputs {
		t.Run(input, func(t *testing.T) {
			_, err := ParseGameVersion(input)
			var parseErr *VersionParseError
			require.ErrorAs(t, err, &parseErr)
		})
	}
}

func TestGameVersionString(t *testing.T) {
	assert.Equal(t, "1.2.3", GameVersion{Major: 1, Minor: 2, Patch: 3}.String())
	assert.Equal(t, "1.2.3-4", GameVersion{Major: 1, Minor: 2, Patch: 3, Build: 4}.String())
}

func TestGameVersionCompare(t *testing.T) {
	base := GameVersion{Major: 1, Minor: 2, Patch: 3, Build: 4}
	assert.Equal(t, 0, base.Compare(GameVersion{Major: 1, Minor: 2, Patch: 3, Build: 4}))
	assert.Equal(t, -1, base.Compare(GameVersion{Major: 2, Minor: 0, Patch: 0}))
	assert.Equal(t, 1, base.Compare(GameVersion{Major: 1, Minor: 2, Patch: 3, Build: 3}))
	assert.True(t, base.Less(GameVersion{Major: 1, Minor: 2, Patch: 4}))
	assert.False(t, base.Less(base))
}
