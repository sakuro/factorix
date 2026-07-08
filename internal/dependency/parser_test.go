package dependency

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func TestParse(t *testing.T) {
	v120 := VersionRequirement{Operator: OpGreaterEqual, Version: mod.MODVersion{Major: 1, Minor: 2}}
	tests := []struct {
		input string
		want  Entry
	}{
		{"base", Entry{MOD: mod.MOD{Name: "base"}, Type: TypeRequired}},
		{"? some-mod >= 1.2.0", Entry{MOD: mod.MOD{Name: "some-mod"}, Type: TypeOptional, Requirement: &v120}},
		{"?compact", Entry{MOD: mod.MOD{Name: "compact"}, Type: TypeOptional}},
		{"(?) hidden-mod", Entry{MOD: mod.MOD{Name: "hidden-mod"}, Type: TypeHiddenOptional}},
		{"! bad-mod", Entry{MOD: mod.MOD{Name: "bad-mod"}, Type: TypeIncompatible}},
		{"~ neutral-mod", Entry{MOD: mod.MOD{Name: "neutral-mod"}, Type: TypeLoadNeutral}},
		{"+ recommended-mod", Entry{MOD: mod.MOD{Name: "recommended-mod"}, Type: TypeRecommended}},
		{"  base  ", Entry{MOD: mod.MOD{Name: "base"}, Type: TypeRequired}},
		{
			"Mod With Spaces >= 1.2",
			Entry{MOD: mod.MOD{Name: "Mod With Spaces"}, Type: TypeRequired, Requirement: &v120},
		},
		{
			"some-mod = 2.0",
			Entry{
				MOD: mod.MOD{Name: "some-mod"}, Type: TypeRequired,
				Requirement: &VersionRequirement{Operator: OpEqual, Version: mod.MODVersion{Major: 2}},
			},
		},
		{
			"some-mod<1.0.5",
			Entry{
				MOD: mod.MOD{Name: "some-mod"}, Type: TypeRequired,
				Requirement: &VersionRequirement{Operator: OpLess, Version: mod.MODVersion{Major: 1, Patch: 5}},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got, err := Parse(tt.input)
			require.NoError(t, err)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestParseDropsOutOfRangeRequirement(t *testing.T) {
	// MODs with version components over 255 exist on the Portal; the
	// requirement is dropped rather than failing the whole dependency.
	got, err := Parse("weird-mod >= 2019.11.20")
	require.NoError(t, err)
	assert.Equal(t, Entry{MOD: mod.MOD{Name: "weird-mod"}, Type: TypeRequired}, got)
}

func TestParseInvalid(t *testing.T) {
	inputs := []string{
		"",
		"   ",
		">= 1.0",         // empty MOD name
		"? >= 1.0",       // empty MOD name after prefix
		"some-mod >=",    // empty version
		"some-mod > x",   // invalid version format
		"some-mod > 1",   // version needs at least two parts
		"some-mod 1.2.3", // version without operator
	}
	for _, input := range inputs {
		t.Run(input, func(t *testing.T) {
			_, err := Parse(input)
			var parseErr *ParseError
			require.ErrorAs(t, err, &parseErr, "input %q", input)
		})
	}
}

func TestEntryString(t *testing.T) {
	for _, s := range []string{"base", "? some-mod >= 1.2.0", "(?) hidden-mod", "! bad-mod", "~ neutral-mod", "+ recommended-mod"} {
		entry, err := Parse(s)
		require.NoError(t, err)
		assert.Equal(t, s, entry.String())
	}
}

func TestVersionRequirementSatisfiedBy(t *testing.T) {
	v100 := mod.MODVersion{Major: 1}
	v110 := mod.MODVersion{Major: 1, Minor: 1}
	v090 := mod.MODVersion{Minor: 9}

	tests := []struct {
		op       Operator
		version  mod.MODVersion
		expected map[mod.MODVersion]bool
	}{
		{OpEqual, v100, map[mod.MODVersion]bool{v100: true, v110: false, v090: false}},
		{OpGreater, v100, map[mod.MODVersion]bool{v100: false, v110: true, v090: false}},
		{OpGreaterEqual, v100, map[mod.MODVersion]bool{v100: true, v110: true, v090: false}},
		{OpLess, v100, map[mod.MODVersion]bool{v100: false, v110: false, v090: true}},
		{OpLessEqual, v100, map[mod.MODVersion]bool{v100: true, v110: false, v090: true}},
	}
	for _, tt := range tests {
		r := VersionRequirement{Operator: tt.op, Version: tt.version}
		for v, want := range tt.expected {
			assert.Equal(t, want, r.SatisfiedBy(v), "%s against %s", r, v)
		}
	}
}
