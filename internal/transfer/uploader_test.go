package transfer

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/httpx"
)

// The Uploader must satisfy the interface the management API consumes.
var _ api.Uploader = (*Uploader)(nil)

func newUploader(t *testing.T, handler http.HandlerFunc) (*Uploader, *httptest.Server) {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	client := httpx.NewClient(httpx.Options{Transport: server.Client().Transport})
	return NewUploader(client, nil), server
}

func modZip(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "test-mod_1.0.0.zip")
	require.NoError(t, os.WriteFile(path, []byte("zip-bytes"), 0o644))
	return path
}

func TestUpload(t *testing.T) {
	var gotFields map[string]string
	var gotFileName, gotFileContentType, gotFileBody string
	uploader, server := newUploader(t, func(w http.ResponseWriter, r *http.Request) {
		require.NoError(t, r.ParseMultipartForm(1<<20))
		gotFields = map[string]string{}
		for name, values := range r.MultipartForm.Value {
			gotFields[name] = values[0]
		}
		file, header, err := r.FormFile("file")
		require.NoError(t, err)
		defer file.Close()
		body, err := io.ReadAll(file)
		require.NoError(t, err)
		gotFileName = header.Filename
		gotFileContentType = header.Header.Get("Content-Type")
		gotFileBody = string(body)
		w.Write([]byte(`{"success": true}`))
	})

	listener := &recordingListener{}
	uploader.Listener = listener

	body, err := uploader.Upload(context.Background(), server.URL+"/upload", modZip(t),
		map[string]string{"description": "A MOD", "license": "MIT"}, "")
	require.NoError(t, err)

	assert.JSONEq(t, `{"success": true}`, string(body))
	assert.Equal(t, map[string]string{"description": "A MOD", "license": "MIT"}, gotFields)
	assert.Equal(t, "test-mod_1.0.0.zip", gotFileName)
	assert.Equal(t, "application/zip", gotFileContentType)
	assert.Equal(t, "zip-bytes", gotFileBody)

	require.NotEmpty(t, listener.started)
	assert.Positive(t, listener.started[0])
	assert.Equal(t, 1, listener.finished)
}

func TestUploadCustomFieldName(t *testing.T) {
	uploader, server := newUploader(t, func(w http.ResponseWriter, r *http.Request) {
		require.NoError(t, r.ParseMultipartForm(1<<20))
		_, _, err := r.FormFile("image")
		assert.NoError(t, err)
		w.Write([]byte(`{}`))
	})

	imagePath := filepath.Join(t.TempDir(), "shot.png")
	require.NoError(t, os.WriteFile(imagePath, []byte("png-bytes"), 0o644))

	_, err := uploader.Upload(context.Background(), server.URL+"/upload", imagePath, nil, "image")
	require.NoError(t, err)
}

func TestUploadMissingFile(t *testing.T) {
	uploader := NewUploader(nil, nil)
	_, err := uploader.Upload(context.Background(), "https://example.com/upload",
		filepath.Join(t.TempDir(), "absent.zip"), nil, "")
	require.ErrorIs(t, err, os.ErrNotExist)
}

func TestUploadServerError(t *testing.T) {
	uploader, server := newUploader(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
	})

	_, err := uploader.Upload(context.Background(), server.URL+"/upload", modZip(t), nil, "")
	var statusErr *httpx.StatusError
	require.ErrorAs(t, err, &statusErr)
	assert.True(t, statusErr.IsClientError())
}

func TestDetectContentType(t *testing.T) {
	assert.Equal(t, "application/zip", detectContentType("mod.ZIP"))
	assert.Equal(t, "image/jpeg", detectContentType("photo.jpeg"))
	assert.Equal(t, "application/octet-stream", detectContentType("data.bin"))
}
