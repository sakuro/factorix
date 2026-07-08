package api

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestMODInfoLastHighlightedAtDateOnly guards against a regression found
// against the real Portal: Krastorio2's last_highlighted_at was returned as
// a bare "2026-05-18" (valid ISO 8601, but not valid RFC3339, which is all
// time.Time's own UnmarshalJSON accepts), while created_at/updated_at were
// full timestamps.
func TestMODInfoLastHighlightedAtDateOnly(t *testing.T) {
	var info MODInfo
	err := json.Unmarshal([]byte(`{
		"name": "Krastorio2",
		"title": "Krastorio 2",
		"owner": "raiguard",
		"created_at": "2020-03-13T15:52:58.015000Z",
		"updated_at": "2026-06-29T03:22:48.111000Z",
		"last_highlighted_at": "2026-05-18"
	}`), &info)
	require.NoError(t, err)

	assert.Equal(t, time.Date(2026, 5, 18, 0, 0, 0, 0, time.UTC), info.LastHighlightedAt)
	assert.True(t, info.CreatedAt.Equal(time.Date(2020, 3, 13, 15, 52, 58, 15000000, time.UTC)))
	assert.True(t, info.UpdatedAt.Equal(time.Date(2026, 6, 29, 3, 22, 48, 111000000, time.UTC)))
}

func TestMODInfoLastHighlightedAtFullTimestamp(t *testing.T) {
	var info MODInfo
	err := json.Unmarshal([]byte(`{"name": "m", "last_highlighted_at": "2024-01-02T03:04:05Z"}`), &info)
	require.NoError(t, err)
	assert.True(t, info.LastHighlightedAt.Equal(time.Date(2024, 1, 2, 3, 4, 5, 0, time.UTC)))
}

func TestMODInfoLastHighlightedAtAbsent(t *testing.T) {
	var info MODInfo
	err := json.Unmarshal([]byte(`{"name": "m"}`), &info)
	require.NoError(t, err)
	assert.True(t, info.LastHighlightedAt.IsZero())
}

func TestMODInfoLastHighlightedAtInvalid(t *testing.T) {
	var info MODInfo
	err := json.Unmarshal([]byte(`{"name": "m", "last_highlighted_at": "not-a-date"}`), &info)
	require.ErrorIs(t, err, ErrInvalidResponse)
}
