package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/httpx"
)

type fakeUploader struct {
	uploadURL string
	filePath  string
	fields    map[string]string
	fieldName string
	response  []byte
}

func (f *fakeUploader) Upload(_ context.Context, uploadURL, filePath string, fields map[string]string, fieldName string) ([]byte, error) {
	f.uploadURL = uploadURL
	f.filePath = filePath
	f.fields = fields
	f.fieldName = fieldName
	return f.response, nil
}

func testAPIKey() func() (APICredential, error) {
	return func() (APICredential, error) {
		return APICredential{apiKey: "key-123"}, nil
	}
}

func newManagementAPI(t *testing.T, uploader Uploader, handler http.HandlerFunc) *MODManagementAPI {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	client := httpx.NewClient(httpx.Options{Transport: server.Client().Transport})
	managementAPI := NewMODManagementAPI(client, uploader, testAPIKey(), nil)
	managementAPI.BaseURL = server.URL
	return managementAPI
}

func TestInitUpload(t *testing.T) {
	var gotAuth, gotPath string
	var gotForm url.Values
	managementAPI := newManagementAPI(t, nil, func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotPath = r.URL.Path
		require.NoError(t, r.ParseForm())
		gotForm = r.PostForm
		w.Write([]byte(`{"upload_url": "https://uploads.example.com/abc"}`))
	})

	uploadURL, err := managementAPI.InitUpload(context.Background(), "test-mod")
	require.NoError(t, err)
	assert.Equal(t, "https://uploads.example.com/abc", uploadURL)
	assert.Equal(t, "Bearer key-123", gotAuth)
	assert.Equal(t, "/api/v2/mods/releases/init_upload", gotPath)
	assert.Equal(t, "test-mod", gotForm.Get("mod"))
}

func TestInitUploadNotFound(t *testing.T) {
	managementAPI := newManagementAPI(t, nil, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	})

	_, err := managementAPI.InitUpload(context.Background(), "missing-mod")
	require.ErrorIs(t, err, ErrMODNotOnPortal)
}

func TestFinishUpload(t *testing.T) {
	uploader := &fakeUploader{response: []byte(`{}`)}
	managementAPI := NewMODManagementAPI(nil, uploader, testAPIKey(), nil)

	var changed []string
	managementAPI.OnMODChanged = func(_ context.Context, name string) {
		changed = append(changed, name)
	}

	metadata := map[string]string{"description": "desc", "license": "MIT"}
	err := managementAPI.FinishUpload(context.Background(), "test-mod", "https://uploads.example.com/abc", "/tmp/test-mod_1.0.0.zip", metadata)
	require.NoError(t, err)

	assert.Equal(t, "https://uploads.example.com/abc", uploader.uploadURL)
	assert.Equal(t, "/tmp/test-mod_1.0.0.zip", uploader.filePath)
	assert.Equal(t, metadata, uploader.fields)
	assert.Equal(t, []string{"test-mod"}, changed)
}

func TestFinishUploadRejectsInvalidMetadata(t *testing.T) {
	managementAPI := NewMODManagementAPI(nil, &fakeUploader{}, testAPIKey(), nil)

	err := managementAPI.FinishUpload(context.Background(), "test-mod", "https://uploads.example.com/abc", "/tmp/x.zip",
		map[string]string{"summary": "not allowed on upload"})
	require.ErrorIs(t, err, ErrInvalidArgument)
}

func TestEditDetails(t *testing.T) {
	var gotForm url.Values
	managementAPI := newManagementAPI(t, nil, func(w http.ResponseWriter, r *http.Request) {
		require.NoError(t, r.ParseForm())
		gotForm = r.PostForm
		w.Write([]byte(`{}`))
	})

	var changed []string
	managementAPI.OnMODChanged = func(_ context.Context, name string) {
		changed = append(changed, name)
	}

	deprecated := true
	err := managementAPI.EditDetails(context.Background(), "test-mod", EditMetadata{
		Title:      "New Title",
		Tags:       []string{"combat", "storage"},
		Deprecated: &deprecated,
	})
	require.NoError(t, err)

	assert.Equal(t, "test-mod", gotForm.Get("mod"))
	assert.Equal(t, "New Title", gotForm.Get("title"))
	assert.Equal(t, []string{"combat", "storage"}, gotForm["tags"])
	assert.Equal(t, "true", gotForm.Get("deprecated"))
	assert.NotContains(t, gotForm, "summary")
	assert.Equal(t, []string{"test-mod"}, changed)
}

func TestFinishImageUpload(t *testing.T) {
	uploader := &fakeUploader{response: []byte(`{"id": "abc123", "url": "https://assets/img.png", "thumbnail": "https://assets/thumb.png"}`)}
	managementAPI := NewMODManagementAPI(nil, uploader, testAPIKey(), nil)

	image, err := managementAPI.FinishImageUpload(context.Background(), "test-mod", "https://uploads.example.com/img", "/tmp/shot.png")
	require.NoError(t, err)
	assert.Equal(t, "abc123", image.ID)
	assert.Equal(t, "image", uploader.fieldName)
}

func TestEditImages(t *testing.T) {
	var gotForm url.Values
	managementAPI := newManagementAPI(t, nil, func(w http.ResponseWriter, r *http.Request) {
		require.NoError(t, r.ParseForm())
		gotForm = r.PostForm
		w.Write([]byte(`{}`))
	})

	err := managementAPI.EditImages(context.Background(), "test-mod", []string{"aaa", "bbb"})
	require.NoError(t, err)
	assert.Equal(t, "aaa,bbb", gotForm.Get("images"))
}
