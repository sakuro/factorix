package httpx

import (
	"errors"
	"fmt"
	"net/http"
)

var (
	ErrNotHTTPS         = errors.New("URL must be HTTPS")
	ErrTooManyRedirects = errors.New("too many redirects")
)

// StatusError reports a non-2xx HTTP response. APIError and APIMessage hold
// the error/message fields of a JSON error body when present.
type StatusError struct {
	StatusCode int
	Status     string
	APIError   string
	APIMessage string
}

func (e *StatusError) Error() string {
	if e.APIMessage != "" {
		return fmt.Sprintf("%s: %s", e.Status, e.APIMessage)
	}
	return e.Status
}

// IsNotFound reports whether the response was a 404.
func (e *StatusError) IsNotFound() bool {
	return e.StatusCode == http.StatusNotFound
}

// IsClientError reports whether the response was a 4xx.
func (e *StatusError) IsClientError() bool {
	return e.StatusCode >= 400 && e.StatusCode < 500
}

// IsServerError reports whether the response was a 5xx.
func (e *StatusError) IsServerError() bool {
	return e.StatusCode >= 500 && e.StatusCode < 600
}
