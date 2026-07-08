package httpx

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// flakyTransport fails with a transport error for the first n calls.
type flakyTransport struct {
	failures int
	calls    int
	bodies   []string
}

func (f *flakyTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	f.calls++
	if req.Body != nil {
		data, _ := io.ReadAll(req.Body)
		req.Body.Close()
		f.bodies = append(f.bodies, string(data))
	}
	if f.calls <= f.failures {
		return nil, errors.New("connection reset")
	}
	return &http.Response{StatusCode: http.StatusOK, Body: io.NopCloser(bytes.NewReader(nil))}, nil
}

func retryOpts() RetryOptions {
	return RetryOptions{Attempts: 3, Delay: time.Millisecond}
}

func TestRetryTransportRecovers(t *testing.T) {
	next := &flakyTransport{failures: 2}
	rt := NewRetryTransport(next, retryOpts())

	req, err := http.NewRequest(http.MethodGet, "https://example.com/", nil)
	require.NoError(t, err)

	resp, err := rt.RoundTrip(req)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	assert.Equal(t, 3, next.calls)
}

func TestRetryTransportGivesUp(t *testing.T) {
	next := &flakyTransport{failures: 10}
	rt := NewRetryTransport(next, retryOpts())

	req, err := http.NewRequest(http.MethodGet, "https://example.com/", nil)
	require.NoError(t, err)

	_, err = rt.RoundTrip(req)
	require.Error(t, err)
	assert.Equal(t, 3, next.calls)
}

func TestRetryTransportReplaysBody(t *testing.T) {
	next := &flakyTransport{failures: 1}
	rt := NewRetryTransport(next, retryOpts())

	// http.NewRequest sets GetBody for bytes.Reader bodies.
	req, err := http.NewRequest(http.MethodPost, "https://example.com/", bytes.NewReader([]byte("payload")))
	require.NoError(t, err)
	require.NotNil(t, req.GetBody)

	_, err = rt.RoundTrip(req)
	require.NoError(t, err)
	assert.Equal(t, []string{"payload", "payload"}, next.bodies)
}

func TestRetryTransportUnreplayableBodyRunsOnce(t *testing.T) {
	next := &flakyTransport{failures: 1}
	rt := NewRetryTransport(next, retryOpts())

	req, err := http.NewRequest(http.MethodPost, "https://example.com/", io.NopCloser(bytes.NewReader([]byte("stream"))))
	require.NoError(t, err)
	req.GetBody = nil

	_, err = rt.RoundTrip(req)
	require.Error(t, err)
	assert.Equal(t, 1, next.calls)
}

func TestRetryTransportRespectsContextCancel(t *testing.T) {
	next := &flakyTransport{failures: 10}
	rt := NewRetryTransport(next, RetryOptions{Attempts: 10, Delay: 50 * time.Millisecond})

	ctx, cancel := context.WithCancel(context.Background())
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://example.com/", nil)
	require.NoError(t, err)

	cancel()
	_, err = rt.RoundTrip(req)
	require.Error(t, err)
	assert.LessOrEqual(t, next.calls, 2)
}
