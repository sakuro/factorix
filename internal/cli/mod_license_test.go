package cli

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMODLicenseListTable(t *testing.T) {
	out, err := runCLI(t, "mod", "license", "list")
	require.NoError(t, err)
	assert.Contains(t, out, "ID")
	assert.Contains(t, out, "NAME")
	assert.Contains(t, out, "default_mit")
	assert.Contains(t, out, "MIT")
	assert.Contains(t, out, "https://raw.githubusercontent.com/spdx/license-list-data/main/text/MIT.txt")
}

func TestMODLicenseListJSON(t *testing.T) {
	out, err := runCLI(t, "mod", "license", "list", "--json")
	require.NoError(t, err)
	assert.Contains(t, out, `"id": "default_mit"`)
	assert.Contains(t, out, `"name": "MIT"`)
}

func TestMODLicenseShow(t *testing.T) {
	out, err := runCLI(t, "mod", "license", "show", "default_mit")
	require.NoError(t, err)
	assert.Contains(t, out, "ID           default_mit")
	assert.Contains(t, out, "Name         MIT")
	assert.Contains(t, out, "https://raw.githubusercontent.com/spdx/license-list-data/main/text/MIT.txt")
}

func TestMODLicenseShowJSON(t *testing.T) {
	out, err := runCLI(t, "mod", "license", "show", "default_mit", "--json")
	require.NoError(t, err)
	assert.Contains(t, out, `"id": "default_mit"`)
}

func TestMODLicenseShowInvalidIdentifier(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "mod", "license", "show", "MIT")
	require.Error(t, err)
	assert.Equal(t, "Invalid license identifier", err.Error())
	assert.Contains(t, out, "✗ Invalid license identifier: MIT\n")
	assert.Contains(t, out, "Valid identifiers: default_mit, ")
}

func TestMODLicenseShowCustomIdentifier(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "mod", "license", "show", "custom_0123456789abcdef01234567")
	require.Error(t, err)
	assert.Equal(t, "Custom license identifiers have no fixed URL", err.Error())
	assert.Contains(t, out, "✗ Custom license identifiers have no fixed URL: custom_0123456789abcdef01234567\n")
}
