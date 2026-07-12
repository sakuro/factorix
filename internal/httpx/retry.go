package httpx

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/avast/retry-go/v5"
)

// RetryTransport retries requests that fail at the transport level
// (connection, TLS, timeout errors) with exponential backoff and jitter.
// HTTP error statuses are responses, not failures, and are never retried.
type RetryTransport struct {
	next     http.RoundTripper
	attempts uint
	delay    time.Duration
	logger   *slog.Logger
}

// RetryOptions configures a RetryTransport.
type RetryOptions struct {
	// Attempts is the total number of tries including the first (default 3).
	Attempts uint
	// Delay is the backoff base interval (default 1s); it doubles per retry
	// with random jitter up to Delay/4.
	Delay  time.Duration
	Logger *slog.Logger
}

// NewRetryTransport wraps next with retries.
func NewRetryTransport(next http.RoundTripper, opts RetryOptions) *RetryTransport {
	if opts.Attempts == 0 {
		opts.Attempts = 3
	}
	if opts.Delay == 0 {
		opts.Delay = time.Second
	}
	if opts.Logger == nil {
		opts.Logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &RetryTransport{next: next, attempts: opts.Attempts, delay: opts.Delay, logger: opts.Logger}
}

// RoundTrip implements http.RoundTripper. Requests with a body but no
// GetBody cannot be replayed and are performed exactly once.
func (t *RetryTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if req.Body != nil && req.GetBody == nil {
		return t.next.RoundTrip(req)
	}

	attempt := 0
	retrier := retry.NewWithData[*http.Response](
		retry.Context(req.Context()),
		retry.Attempts(t.attempts),
		retry.Delay(t.delay),
		retry.MaxJitter(t.delay/4),
		retry.DelayType(retry.CombineDelay(retry.BackOffDelay, retry.RandomDelay)),
		retry.RetryIf(func(err error) bool {
			return !errors.Is(err, context.Canceled) && !errors.Is(err, context.DeadlineExceeded)
		}),
		retry.OnRetry(func(n uint, err error) {
			t.logger.Warn("Retrying HTTP request", "attempt", n+1, "url", MaskURL(req.URL, nil), "error", err)
		}),
		retry.LastErrorOnly(true),
	)
	return retrier.Do(func() (*http.Response, error) {
		r := req
		if attempt > 0 && req.GetBody != nil {
			body, err := req.GetBody()
			if err != nil {
				return nil, retry.Unrecoverable(err)
			}
			r = req.Clone(req.Context())
			r.Body = body
		}
		attempt++
		return t.next.RoundTrip(r)
	})
}
