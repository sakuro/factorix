package httpx

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// newTLSClient returns a Client wired to the TLS test server's certificates.
func newTLSClient(t *testing.T, server *httptest.Server) *Client {
	t.Helper()
	return NewClient(Options{Transport: server.Client().Transport})
}

func TestClientGet(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("hello"))
	}))
	defer server.Close()

	resp, err := newTLSClient(t, server).Get(context.Background(), server.URL)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	assert.Equal(t, []byte("hello"), resp.Body)
}

func TestClientRejectsPlainHTTP(t *testing.T) {
	client := NewClient(Options{})
	_, err := client.Get(context.Background(), "http://example.com/")
	require.ErrorIs(t, err, ErrNotHTTPS)
}

func TestClientNotFoundWithAPIError(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(`{"error": "UnknownMod", "message": "Mod not found"}`))
	}))
	defer server.Close()

	_, err := newTLSClient(t, server).Get(context.Background(), server.URL)
	var statusErr *StatusError
	require.ErrorAs(t, err, &statusErr)
	assert.True(t, statusErr.IsNotFound())
	assert.True(t, statusErr.IsClientError())
	assert.False(t, statusErr.IsServerError())
	assert.Equal(t, "UnknownMod", statusErr.APIError)
	assert.Equal(t, "Mod not found", statusErr.APIMessage)
}

func TestClientServerError(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	_, err := newTLSClient(t, server).Get(context.Background(), server.URL)
	var statusErr *StatusError
	require.ErrorAs(t, err, &statusErr)
	assert.True(t, statusErr.IsServerError())
}

func TestClientFollowsRedirects(t *testing.T) {
	var server *httptest.Server
	server = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/from" {
			http.Redirect(w, r, server.URL+"/to", http.StatusFound)
			return
		}
		w.Write([]byte("landed"))
	}))
	defer server.Close()

	resp, err := newTLSClient(t, server).Get(context.Background(), server.URL+"/from")
	require.NoError(t, err)
	assert.Equal(t, []byte("landed"), resp.Body)
}

func TestClientPost(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "application/x-www-form-urlencoded", r.Header.Get("Content-Type"))
		w.Write([]byte("posted"))
	}))
	defer server.Close()

	resp, err := newTLSClient(t, server).Post(context.Background(), server.URL,
		"application/x-www-form-urlencoded", strings.NewReader("a=b"))
	require.NoError(t, err)
	assert.Equal(t, []byte("posted"), resp.Body)
}

func TestMaskURL(t *testing.T) {
	u, err := url.Parse("https://example.com/download?username=alice&token=secret&page=2")
	require.NoError(t, err)

	masked := MaskURL(u, []string{"username", "token", "secure"})
	assert.Contains(t, masked, "username=%2A%2A%2A%2A%2A")
	assert.Contains(t, masked, "token=%2A%2A%2A%2A%2A")
	assert.Contains(t, masked, "page=2")
	assert.NotContains(t, masked, "secret")
	assert.NotContains(t, masked, "alice")

	// The original URL is untouched.
	assert.Contains(t, u.String(), "token=secret")

	// No masked params: returned unchanged.
	assert.Equal(t, u.String(), MaskURL(u, nil))
}
