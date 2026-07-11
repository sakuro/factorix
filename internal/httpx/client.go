// Package httpx wraps net/http with HTTPS enforcement, credential masking
// in logs, and retry/cache decorators implemented as http.RoundTripper
// chains. Named httpx to avoid shadowing the stdlib http package.
package httpx

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// TestRootCAs is the trust store used for every transport NewBaseTransport
// builds, instead of the OS certificate store, whenever it is non-nil. It
// exists so integration tests can point commands at an httptest TLS server
// without weakening HTTPS enforcement itself; production code never sets
// it. RootCAs is an in-memory, cross-platform trust list, unlike the
// SSL_CERT_FILE environment variable Go's system pool loader only honors on
// some platforms (not macOS).
var TestRootCAs *x509.CertPool

const maxRedirects = 10

// Response is a fully-read HTTP response. URL is the final URL after
// redirects.
type Response struct {
	StatusCode int
	Header     http.Header
	Body       []byte
	URL        *url.URL
}

// Options configures a Client.
type Options struct {
	// Transport is the RoundTripper chain to use; nil uses NewBaseTransport
	// with the timeouts below.
	Transport      http.RoundTripper
	ConnectTimeout time.Duration
	ReadTimeout    time.Duration
	// MaskedParams are query parameter names whose values are masked in logs.
	MaskedParams []string
	Logger       *slog.Logger
}

// Client is a thin wrapper around net/http.Client. All request URLs must be
// HTTPS.
type Client struct {
	hc           *http.Client
	maskedParams []string
	logger       *slog.Logger
}

// NewBaseTransport builds the bottom of the RoundTripper chain. The connect
// timeout bounds dialing and the TLS handshake; the read timeout bounds the
// wait for response headers. Go has no discrete write timeout — in-flight
// requests are bounded by the request context instead.
func NewBaseTransport(connectTimeout, readTimeout time.Duration) *http.Transport {
	t := &http.Transport{
		Proxy:                 http.ProxyFromEnvironment,
		DialContext:           (&net.Dialer{Timeout: connectTimeout}).DialContext,
		TLSHandshakeTimeout:   connectTimeout,
		ResponseHeaderTimeout: readTimeout,
		ForceAttemptHTTP2:     true,
	}
	if TestRootCAs != nil {
		t.TLSClientConfig = &tls.Config{RootCAs: TestRootCAs}
	}
	return t
}

// NewClient builds a Client.
func NewClient(opts Options) *Client {
	logger := opts.Logger
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	transport := opts.Transport
	if transport == nil {
		transport = NewBaseTransport(opts.ConnectTimeout, opts.ReadTimeout)
	}
	maskedParams := opts.MaskedParams

	hc := &http.Client{
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= maxRedirects {
				return ErrTooManyRedirects
			}
			if req.URL.Scheme != "https" {
				return ErrNotHTTPS
			}
			logger.Info("Following redirect", "location", MaskURL(req.URL, maskedParams))
			return nil
		},
	}
	return &Client{hc: hc, maskedParams: maskedParams, logger: logger}
}

// Do executes a request and returns the live response; the caller must close
// the body. Non-2xx statuses are returned as responses, not errors — use the
// buffered helpers for status checking.
func (c *Client) Do(ctx context.Context, method, rawURL string, header http.Header, body io.Reader) (*http.Response, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return nil, err
	}
	if u.Scheme != "https" {
		return nil, ErrNotHTTPS
	}

	req, err := http.NewRequestWithContext(ctx, method, rawURL, body)
	if err != nil {
		return nil, err
	}
	for key, values := range header {
		req.Header[key] = values
	}

	c.logger.Info("HTTP request", "method", method, "url", MaskURL(u, c.maskedParams))
	return c.hc.Do(req)
}

// Request executes a request and returns the buffered response, mapping
// non-2xx statuses to StatusError.
func (c *Client) Request(ctx context.Context, method, rawURL string, header http.Header, body io.Reader) (*Response, error) {
	return c.buffered(ctx, method, rawURL, header, body)
}

// Get executes a GET request and returns the buffered response.
func (c *Client) Get(ctx context.Context, rawURL string) (*Response, error) {
	return c.buffered(ctx, http.MethodGet, rawURL, nil, nil)
}

// Head executes a HEAD request.
func (c *Client) Head(ctx context.Context, rawURL string) (*Response, error) {
	return c.buffered(ctx, http.MethodHead, rawURL, nil, nil)
}

// Post executes a POST request and returns the buffered response.
func (c *Client) Post(ctx context.Context, rawURL, contentType string, body io.Reader) (*Response, error) {
	header := http.Header{}
	if contentType != "" {
		header.Set("Content-Type", contentType)
	}
	return c.buffered(ctx, http.MethodPost, rawURL, header, body)
}

// GetStream executes a GET request and returns the live response after
// checking the status; the caller must close the body.
func (c *Client) GetStream(ctx context.Context, rawURL string) (*http.Response, error) {
	resp, err := c.Do(ctx, http.MethodGet, rawURL, nil, nil)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return resp, nil
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return nil, c.statusError(resp, body)
}

func (c *Client) buffered(ctx context.Context, method, rawURL string, header http.Header, body io.Reader) (*Response, error) {
	resp, err := c.Do(ctx, method, rawURL, header, body)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		err := c.statusError(resp, data)
		c.logger.Error("HTTP error response", "status", resp.Status, "error", err)
		return nil, err
	}
	return &Response{StatusCode: resp.StatusCode, Header: resp.Header, Body: data, URL: resp.Request.URL}, nil
}

func (c *Client) statusError(resp *http.Response, body []byte) *StatusError {
	statusErr := &StatusError{StatusCode: resp.StatusCode, Status: resp.Status}
	if strings.Contains(resp.Header.Get("Content-Type"), "application/json") && len(body) > 0 {
		var apiError struct {
			Error   string `json:"error"`
			Message string `json:"message"`
		}
		if json.Unmarshal(body, &apiError) == nil {
			statusErr.APIError = apiError.Error
			statusErr.APIMessage = apiError.Message
		}
	}
	return statusErr
}

// MaskURL renders the URL with the values of the given query parameters
// replaced by "*****", for credential-safe logging.
func MaskURL(u *url.URL, maskedParams []string) string {
	if u.RawQuery == "" || len(maskedParams) == 0 {
		return u.String()
	}
	masked := *u
	query := masked.Query()
	for _, param := range maskedParams {
		if query.Has(param) {
			query.Set(param, "*****")
		}
	}
	masked.RawQuery = query.Encode()
	return masked.String()
}
