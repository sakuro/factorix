package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDevUploadNewMODAgainstMockPortal(t *testing.T) {
	newSandbox(t)
	portal := newMockPortal(t) // new-mod does not exist on the portal
	portal.withPortal(t)

	zipPath := filepath.Join(t.TempDir(), "new-mod_1.0.0.zip")
	writeMODZip(t, zipPath, "new-mod", "1.0.0")

	out, err := runCLI(t, "dev", "upload", zipPath, "--category", "content")
	require.NoError(t, err)
	assert.Contains(t, out, "Upload completed successfully!")

	// New MOD: init_publish, then finish-upload with metadata included
	// (no separate edit_details call).
	require.Len(t, portal.managementCalls, 1)
	assert.Equal(t, "/api/v2/mods/init_publish", portal.managementCalls[0].Path)
	assert.Equal(t, "new-mod", portal.managementCalls[0].MODArg)
	assert.Equal(t, "Bearer test-api-key", portal.managementCalls[0].Auth)
}

func TestDevUploadExistingMODAgainstMockPortal(t *testing.T) {
	newSandbox(t)
	portal := newMockPortal(t, portalMOD{Name: "existing-mod", Title: "Existing MOD", Owner: "alice"})
	portal.withPortal(t)

	zipPath := filepath.Join(t.TempDir(), "existing-mod_2.0.0.zip")
	writeMODZip(t, zipPath, "existing-mod", "2.0.0")

	out, err := runCLI(t, "dev", "upload", zipPath, "--category", "content")
	require.NoError(t, err)
	assert.Contains(t, out, "Upload completed successfully!")

	// Existing MOD: init_upload for the release, then a separate
	// edit_details call for the metadata.
	require.Len(t, portal.managementCalls, 2)
	assert.Equal(t, "/api/v2/mods/releases/init_upload", portal.managementCalls[0].Path)
	assert.Equal(t, "/api/v2/mods/edit_details", portal.managementCalls[1].Path)
	assert.Equal(t, []string{"content"}, portal.managementCalls[1].Form["category"])
}

func TestDevUploadRequiresAPIKey(t *testing.T) {
	newSandbox(t)
	portal := newMockPortal(t)
	portal.withPortal(t)
	t.Setenv("FACTORIO_API_KEY", "")

	zipPath := filepath.Join(t.TempDir(), "new-mod_1.0.0.zip")
	writeMODZip(t, zipPath, "new-mod", "1.0.0")

	_, err := runCLI(t, "dev", "upload", zipPath)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "FACTORIO_API_KEY")
}

func TestDevEditAgainstMockPortal(t *testing.T) {
	newSandbox(t)
	portal := newMockPortal(t, portalMOD{Name: "some-mod", Title: "Some MOD", Owner: "alice"})
	portal.withPortal(t)

	out, err := runCLI(t, "dev", "edit", "some-mod", "--title", "New Title", "--summary", "New summary")
	require.NoError(t, err)
	assert.Contains(t, out, "Metadata updated successfully!")

	require.Len(t, portal.managementCalls, 1)
	call := portal.managementCalls[0]
	assert.Equal(t, "/api/v2/mods/edit_details", call.Path)
	assert.Equal(t, []string{"some-mod"}, call.Form["mod"])
	assert.Equal(t, []string{"New Title"}, call.Form["title"])
	assert.Equal(t, []string{"New summary"}, call.Form["summary"])
}

func TestDevImageListAgainstMockPortal(t *testing.T) {
	newSandbox(t)
	portal := newMockPortal(t, portalMOD{
		Name: "some-mod", Title: "Some MOD", Owner: "alice",
		Images: []portalImage{{ID: "abc123", Thumbnail: "https://example.com/thumb.png", URL: "https://example.com/full.png"}},
	})
	portal.withPortal(t)

	out, err := runCLI(t, "dev", "image", "list", "some-mod")
	require.NoError(t, err)
	assert.Contains(t, out, "abc123")
	assert.Contains(t, out, "https://example.com/thumb.png")
}

func TestDevImageAddAgainstMockPortal(t *testing.T) {
	s := newSandbox(t)
	portal := newMockPortal(t)
	portal.imageUploadResponse = portalImage{ID: "new-img-id", Thumbnail: "https://example.com/t.png", URL: "https://example.com/f.png"}
	portal.withPortal(t)

	imagePath := filepath.Join(s.root, "screenshot.png")
	require.NoError(t, os.WriteFile(imagePath, []byte("fake-png-content"), 0o644))

	out, err := runCLI(t, "dev", "image", "add", "some-mod", imagePath)
	require.NoError(t, err)
	assert.Contains(t, out, "Image added successfully!")
	assert.Contains(t, out, "new-img-id")

	require.Len(t, portal.managementCalls, 1)
	assert.Equal(t, "/api/v2/mods/images/add", portal.managementCalls[0].Path)
}

func TestDevImageEditAgainstMockPortal(t *testing.T) {
	newSandbox(t)
	portal := newMockPortal(t)
	portal.withPortal(t)

	out, err := runCLI(t, "dev", "image", "edit", "some-mod", "img1", "img2")
	require.NoError(t, err)
	assert.Contains(t, out, "Image list updated successfully!")

	require.Len(t, portal.managementCalls, 1)
	call := portal.managementCalls[0]
	assert.Equal(t, "/api/v2/mods/images/edit", call.Path)
	assert.Equal(t, []string{"img1,img2"}, call.Form["images"])
}
