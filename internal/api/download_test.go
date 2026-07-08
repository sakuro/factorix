package api

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func testCredentials() func() (ServiceCredential, error) {
	return func() (ServiceCredential, error) {
		return ServiceCredential{username: "alice", token: "tok"}, nil
	}
}

func TestMODDownloadURL(t *testing.T) {
	downloadAPI := NewMODDownloadAPI(testCredentials())

	downloadURL, err := downloadAPI.DownloadURL("/download/test-mod/aaa")
	require.NoError(t, err)
	assert.Equal(t, "https://mods.factorio.com/download/test-mod/aaa?token=tok&username=alice", downloadURL)
}

func TestMODDownloadURLRejectsAbsolute(t *testing.T) {
	downloadAPI := NewMODDownloadAPI(testCredentials())

	_, err := downloadAPI.DownloadURL("https://evil.example.com/download")
	require.ErrorIs(t, err, ErrInvalidArgument)
}
