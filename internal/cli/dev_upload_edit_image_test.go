package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
)

func TestDevUploadFileValidation(t *testing.T) {
	s := newSandbox(t)

	_, err := runCLI(t, "dev", "upload", filepath.Join(s.root, "missing.zip"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "File not found: ")

	dir := filepath.Join(s.root, "a-directory.zip")
	require.NoError(t, os.Mkdir(dir, 0o755))
	_, err = runCLI(t, "dev", "upload", dir)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Not a file: ")

	notZip := filepath.Join(s.root, "mod.tar")
	require.NoError(t, os.WriteFile(notZip, []byte("x"), 0o644))
	_, err = runCLI(t, "dev", "upload", notZip)
	require.Error(t, err)
	assert.Equal(t, "File must be a .zip file", err.Error())
}

func TestDevEditRejectsInvalidLicense(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "dev", "edit", "some-mod", "--license", "MIT")
	require.Error(t, err)
	assert.Equal(t, "Invalid license identifier", err.Error())
	assert.Contains(t, out, "✗ Invalid license identifier: MIT\n")
	assert.Contains(t, out, "Valid identifiers: default_mit, ")
	assert.Contains(t, out, "Custom licenses: custom_<24 hex chars>")
}

func TestDevEditRequiresMetadata(t *testing.T) {
	newSandbox(t)
	out, err := runCLI(t, "dev", "edit", "some-mod")
	require.Error(t, err)
	assert.Equal(t, "No metadata options provided", err.Error())
	assert.Contains(t, out, "✗ At least one metadata option must be provided\n")
	assert.Contains(t, out, "Available options: --description, --summary, --title, --category, --tags, --license, --homepage, --source-url, --faq, --deprecated\n")
}

func TestDevImageAddMissingFile(t *testing.T) {
	s := newSandbox(t)
	_, err := runCLI(t, "dev", "image", "add", "some-mod", filepath.Join(s.root, "missing.png"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Image file not found: ")
}

func sampleImages() []api.Image {
	return []api.Image{
		{ID: "abc123", Thumbnail: "https://assets.example/thumb/abc123.png", URL: "https://assets.example/full/abc123.png"},
		{ID: "d4", Thumbnail: "https://a.example/t.png", URL: "https://a.example/f.png"},
	}
}

func TestOutputImageTable(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf}
	outputImageTable(p, sampleImages())

	out := buf.String()
	assert.Equal(t, "ID      THUMBNAIL                                URL\n"+
		"abc123  https://assets.example/thumb/abc123.png  https://assets.example/full/abc123.png\n"+
		"d4      https://a.example/t.png                  https://a.example/f.png\n", out)
}

func TestOutputImageTableEmpty(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	var buf bytes.Buffer
	p := &printer{out: &buf}
	outputImageTable(p, nil)
	assert.Equal(t, "ℹ No images found\n", buf.String())
}

func TestOutputImageJSON(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf}
	require.NoError(t, outputImageJSON(p, sampleImages()[1:]))
	assert.Equal(t, `[
  {
    "id": "d4",
    "thumbnail": "https://a.example/t.png",
    "url": "https://a.example/f.png"
  }
]
`, buf.String())
}

func TestOutputImageJSONEmpty(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf}
	require.NoError(t, outputImageJSON(p, nil))
	assert.Equal(t, "[]\n", buf.String())
}

func TestIsEmptyEditMetadata(t *testing.T) {
	assert.True(t, isEmptyEditMetadata(api.EditMetadata{}))
	assert.False(t, isEmptyEditMetadata(api.EditMetadata{Title: "t"}))
	f := false
	assert.False(t, isEmptyEditMetadata(api.EditMetadata{Deprecated: &f}))
}
