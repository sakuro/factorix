package api

import (
	"testing"

	"github.com/stretchr/testify/assert"
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
