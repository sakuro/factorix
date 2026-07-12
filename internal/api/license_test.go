package api

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestValidLicenseIdentifier(t *testing.T) {
	for _, id := range LicenseIdentifiers() {
		assert.True(t, ValidLicenseIdentifier(id), id)
	}
	assert.True(t, ValidLicenseIdentifier("custom_0123456789abcdef01234567"))

	assert.False(t, ValidLicenseIdentifier("MIT"))
	assert.False(t, ValidLicenseIdentifier("default_wtfpl"))
	assert.False(t, ValidLicenseIdentifier("custom_0123456789ABCDEF01234567")) // uppercase hex
	assert.False(t, ValidLicenseIdentifier("custom_0123"))                     // too short
	assert.False(t, ValidLicenseIdentifier("custom_0123456789abcdef012345678"))
}

func TestStandardLicenses(t *testing.T) {
	licenses := StandardLicenses()
	require.Len(t, licenses, len(LicenseIdentifiers()))
	for i, license := range licenses {
		assert.Equal(t, LicenseIdentifiers()[i], license.ID)
		assert.NotEmpty(t, license.Name)
		assert.NotEmpty(t, license.URL)
	}
}

func TestStandardLicenseFor(t *testing.T) {
	license, ok := StandardLicenseFor("default_mit")
	require.True(t, ok)
	assert.Equal(t, "MIT", license.Name)
	assert.Equal(t, "https://raw.githubusercontent.com/spdx/license-list-data/main/text/MIT.txt", license.URL)

	_, ok = StandardLicenseFor("custom_0123456789abcdef01234567")
	assert.False(t, ok)

	_, ok = StandardLicenseFor("MIT")
	assert.False(t, ok)
}
