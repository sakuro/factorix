package progress

import (
	"bytes"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewRendererNilWhenNotATerminal(t *testing.T) {
	// os.Stderr is not a TTY under `go test`.
	assert.Nil(t, NewRenderer())
}

func TestNilRendererListenerIsNil(t *testing.T) {
	var r *Renderer
	assert.Nil(t, r.Listener("some.zip"))
	r.Wait() // must not panic
}

func TestRendererRendersProgress(t *testing.T) {
	var buf bytes.Buffer
	r := newRenderer(&buf)

	l := r.Listener("some.zip")
	require.NotNil(t, l)
	l.OnStart(100)
	l.OnProgress(50)
	l.OnProgress(100)
	l.OnFinish()
	r.Wait()

	out := buf.String()
	assert.Contains(t, out, "some.zip")
	assert.Contains(t, out, "100 %")
}

func TestRendererMultipleBars(t *testing.T) {
	var buf bytes.Buffer
	r := newRenderer(&buf)

	first := r.Listener("first.zip")
	second := r.Listener("second.zip")
	first.OnStart(10)
	second.OnStart(20)
	first.OnProgress(10)
	first.OnFinish()
	second.OnProgress(20)
	second.OnFinish()
	r.Wait()

	out := buf.String()
	assert.True(t, strings.Contains(out, "first.zip") && strings.Contains(out, "second.zip"))
}

func TestRendererUnknownTotal(t *testing.T) {
	var buf bytes.Buffer
	r := newRenderer(&buf)

	l := r.Listener("stream.zip")
	l.OnStart(-1)
	l.OnProgress(42)
	l.OnFinish()
	r.Wait()

	assert.Contains(t, buf.String(), "stream.zip")
}
