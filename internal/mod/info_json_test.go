package mod

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseInfoJSON(t *testing.T) {
	info, err := ParseInfoJSON([]byte(`{
		"name": "test-mod",
		"version": "1.2.3",
		"title": "Test MOD",
		"author": "someone",
		"description": "A test MOD",
		"factorio_version": "2.0",
		"dependencies": ["base >= 2.0", "? optional-mod"]
	}`))
	require.NoError(t, err)
	assert.Equal(t, InfoJSON{
		Name:            "test-mod",
		Version:         MODVersion{Major: 1, Minor: 2, Patch: 3},
		Title:           "Test MOD",
		Author:          "someone",
		Description:     "A test MOD",
		FactorioVersion: "2.0",
		Dependencies:    []string{"base >= 2.0", "? optional-mod"},
	}, info)
}

func TestParseInfoJSONOptionalFieldsOmitted(t *testing.T) {
	info, err := ParseInfoJSON([]byte(`{"name": "m", "version": "1.0.0", "title": "M", "author": "a"}`))
	require.NoError(t, err)
	assert.Empty(t, info.Description)
	assert.Empty(t, info.FactorioVersion)
	assert.Empty(t, info.Dependencies)
}

func TestParseInfoJSONMissingRequiredFields(t *testing.T) {
	_, err := ParseInfoJSON([]byte(`{"name": "m", "title": "M"}`))
	var ffe *FileFormatError
	require.ErrorAs(t, err, &ffe)
	assert.Contains(t, ffe.Msg, "version")
	assert.Contains(t, ffe.Msg, "author")
	assert.NotContains(t, ffe.Msg, "name")
}

func TestParseInfoJSONInvalidJSON(t *testing.T) {
	_, err := ParseInfoJSON([]byte(`{`))
	var ffe *FileFormatError
	require.ErrorAs(t, err, &ffe)
}

func TestParseInfoJSONInvalidVersion(t *testing.T) {
	_, err := ParseInfoJSON([]byte(`{"name": "m", "version": "x.y", "title": "M", "author": "a"}`))
	var ffe *FileFormatError
	require.ErrorAs(t, err, &ffe)
}
