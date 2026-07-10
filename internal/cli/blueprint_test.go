package cli

import (
	"os"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// The blueprint string and JSON from the e2e cases (e2e/cases/blueprint).
const (
	e2eBlueprintString = "0eNqrVkrKKU0tKMrMK1GyqlbKLEnNVbJCEtNRyklMSs0BiqUapQJ5ZalFxZn5eUpWRhaGJuaWRuamZkBkYlFbCwCnbBdF"
	e2eBlueprintJSON   = `{"blueprint": {"item": "blueprint", "label": "e2e", "version": 281479275675648}}`
)

// The e2e contract: a blueprint string followed by a trailing newline.
var blueprintStringPattern = regexp.MustCompile(`\A0[A-Za-z0-9+/=]+\n\z`)

func TestBlueprintDecodeStdin(t *testing.T) {
	out, err := runCLIWithStdin(t, e2eBlueprintString, "blueprint", "decode")
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "blueprint", "decode", "expected_stdout.txt"), out)
}

func TestBlueprintEncodeStdin(t *testing.T) {
	out, err := runCLIWithStdin(t, e2eBlueprintJSON+"\n", "blueprint", "encode")
	require.NoError(t, err)
	assert.Regexp(t, blueprintStringPattern, out)

	// The produced string decodes back to the same JSON.
	decoded, err := runCLIWithStdin(t, out, "blueprint", "decode")
	require.NoError(t, err)
	assert.Equal(t, expectedStdout(t, "blueprint", "decode", "expected_stdout.txt"), decoded)
}

func TestBlueprintDecodeFileToFile(t *testing.T) {
	dir := t.TempDir()
	inPath := filepath.Join(dir, "blueprint.txt")
	outPath := filepath.Join(dir, "decoded.json")
	// A trailing newline in the input file is stripped, as in Ruby.
	require.NoError(t, os.WriteFile(inPath, []byte(e2eBlueprintString+"\n"), 0o644))

	out, err := runCLI(t, "blueprint", "decode", inPath, "-o", outPath)
	require.NoError(t, err)
	assert.Empty(t, out)

	data, err := os.ReadFile(outPath)
	require.NoError(t, err)
	// The file gets the same newline-terminated JSON as stdout.
	assert.Equal(t, expectedStdout(t, "blueprint", "decode", "expected_stdout.txt"), string(data))
}

func TestBlueprintEncodeFileToFile(t *testing.T) {
	dir := t.TempDir()
	inPath := filepath.Join(dir, "decoded.json")
	outPath := filepath.Join(dir, "blueprint.txt")
	require.NoError(t, os.WriteFile(inPath, []byte(e2eBlueprintJSON), 0o644))

	out, err := runCLI(t, "blueprint", "encode", inPath, "-o", outPath)
	require.NoError(t, err)
	assert.Empty(t, out)

	data, err := os.ReadFile(outPath)
	require.NoError(t, err)
	assert.Regexp(t, blueprintStringPattern, string(data))
}

func TestBlueprintDecodeInvalidInput(t *testing.T) {
	_, err := runCLIWithStdin(t, "1nonsense", "blueprint", "decode")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unsupported blueprint version")
}

func TestBlueprintEncodeInvalidJSON(t *testing.T) {
	_, err := runCLIWithStdin(t, "{not json", "blueprint", "encode")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid JSON")
}
