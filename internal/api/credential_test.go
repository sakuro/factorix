package api

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func clearCredentialEnv(t *testing.T) {
	t.Helper()
	for _, v := range []string{envUsername, envToken, envAPIKey} {
		t.Setenv(v, "")
		os.Unsetenv(v)
	}
}

func playerDataFile(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "player-data.json")
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
	return path
}

func TestLoadServiceCredentialFromEnv(t *testing.T) {
	clearCredentialEnv(t)
	t.Setenv(envUsername, "alice")
	t.Setenv(envToken, "secret")

	credential, err := LoadServiceCredential("/nonexistent")
	require.NoError(t, err)
	assert.Equal(t, "alice", credential.Username())
	assert.Equal(t, "secret", credential.Token())
}

func TestLoadServiceCredentialPartialEnv(t *testing.T) {
	clearCredentialEnv(t)
	t.Setenv(envUsername, "alice")

	_, err := LoadServiceCredential("/nonexistent")
	require.ErrorIs(t, err, ErrCredential)
}

func TestLoadServiceCredentialFromPlayerData(t *testing.T) {
	clearCredentialEnv(t)
	path := playerDataFile(t, `{"service-username": "bob", "service-token": "tok"}`)

	credential, err := LoadServiceCredential(path)
	require.NoError(t, err)
	assert.Equal(t, "bob", credential.Username())
	assert.Equal(t, "tok", credential.Token())
}

func TestLoadServiceCredentialPlayerDataMissingFields(t *testing.T) {
	clearCredentialEnv(t)
	path := playerDataFile(t, `{"service-username": "bob"}`)

	_, err := LoadServiceCredential(path)
	require.ErrorIs(t, err, ErrCredential)
	assert.Contains(t, err.Error(), "service-token")
}

func TestLoadServiceCredentialNoSources(t *testing.T) {
	clearCredentialEnv(t)
	_, err := LoadServiceCredential(filepath.Join(t.TempDir(), "absent.json"))
	require.ErrorIs(t, err, ErrCredential)
}

func TestServiceCredentialMasking(t *testing.T) {
	clearCredentialEnv(t)
	t.Setenv(envUsername, "alice")
	t.Setenv(envToken, "secret")
	credential, err := LoadServiceCredential("/nonexistent")
	require.NoError(t, err)

	rendered := fmt.Sprintf("%v / %s", credential, credential)
	assert.NotContains(t, rendered, "alice")
	assert.NotContains(t, rendered, "secret")
}

func TestLoadAPICredential(t *testing.T) {
	clearCredentialEnv(t)

	_, err := LoadAPICredential()
	require.ErrorIs(t, err, ErrCredential)

	t.Setenv(envAPIKey, "key-123")
	credential, err := LoadAPICredential()
	require.NoError(t, err)
	assert.Equal(t, "key-123", credential.APIKey())
	assert.NotContains(t, fmt.Sprintf("%v", credential), "key-123")
}
