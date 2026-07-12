package mod

import (
	"slices"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMODIsBase(t *testing.T) {
	assert.True(t, MOD{Name: "base"}.IsBase())
	assert.False(t, MOD{Name: "Base"}.IsBase())
	assert.False(t, MOD{Name: "space-age"}.IsBase())
}

func TestMODIsExpansion(t *testing.T) {
	for _, name := range []string{"space-age", "quality", "elevated-rails", "recycler"} {
		assert.True(t, MOD{Name: name}.IsExpansion(), name)
	}
	assert.False(t, MOD{Name: "base"}.IsExpansion())
	assert.False(t, MOD{Name: "Space-Age"}.IsExpansion())
}

func TestMODCompare(t *testing.T) {
	mods := []MOD{
		{Name: "zebra"},
		{Name: "base"},
		{Name: "alpha"},
	}
	slices.SortFunc(mods, MOD.Compare)
	assert.Equal(t, []MOD{{Name: "base"}, {Name: "alpha"}, {Name: "zebra"}}, mods)

	assert.Equal(t, 0, MOD{Name: "base"}.Compare(MOD{Name: "base"}))
	assert.Equal(t, -1, MOD{Name: "base"}.Compare(MOD{Name: "aaa"}))
	assert.Equal(t, 1, MOD{Name: "aaa"}.Compare(MOD{Name: "base"}))
}
