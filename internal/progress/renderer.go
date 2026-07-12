package progress

import (
	"io"
	"os"

	"github.com/vbauerster/mpb/v8"
	"github.com/vbauerster/mpb/v8/decor"
	"golang.org/x/term"
)

// Renderer draws progress bars on an output stream. A nil Renderer hands
// out nil listeners, so transfers run silently — NewRenderer returns nil
// when stderr is not a terminal, keeping piped and redirected output clean
// (the same output.tty? check as Ruby's Presenter).
type Renderer struct {
	container *mpb.Progress
}

// NewRenderer returns a stderr renderer, or nil when stderr is not a TTY.
func NewRenderer() *Renderer {
	if !term.IsTerminal(int(os.Stderr.Fd())) {
		return nil
	}
	return newRenderer(os.Stderr)
}

// newRenderer builds a renderer writing to w unconditionally, skipping the
// stderr TTY check — for tests, which supply their own writer.
// WithAutoRefresh is needed because mpb otherwise only ticks its refresh
// loop when it detects the output is itself a terminal, which a
// bytes.Buffer never is; production callers already gate on a real TTY via
// NewRenderer, so this is a no-op there.
// Width is left unset so mpb sizes bars to the terminal's actual width
// instead of a fixed column count.
func newRenderer(w io.Writer) *Renderer {
	return &Renderer{container: mpb.New(mpb.WithOutput(w), mpb.WithAutoRefresh())}
}

// Listener adds a bar labeled with title and returns a listener driving
// it. Safe to call from concurrent goroutines.
func (r *Renderer) Listener(title string) Listener {
	if r == nil {
		return nil
	}
	bar := r.container.AddBar(0,
		mpb.PrependDecorators(decor.Name(title+" ")),
		mpb.AppendDecorators(
			decor.Percentage(decor.WCSyncSpace),
			decor.Counters(decor.SizeB1024(0), " % .1f / % .1f", decor.WCSyncSpace),
		),
	)
	return &barListener{bar: bar}
}

// Wait blocks until every bar has rendered its final state; call after all
// transfers finish.
func (r *Renderer) Wait() {
	if r != nil {
		r.container.Wait()
	}
}

type barListener struct {
	bar *mpb.Bar
}

// OnStart reports the total (-1 when unknown, leaving the bar indeterminate).
// A second OnStart rewinds the bar: a retried transfer restarts.
func (l *barListener) OnStart(total int64) {
	l.bar.SetCurrent(0)
	if total >= 0 {
		l.bar.SetTotal(total, false)
	}
}

func (l *barListener) OnProgress(current int64) {
	l.bar.SetCurrent(current)
}

// OnFinish completes the bar; a negative total makes mpb adopt the current
// value, so bars without a known size still complete cleanly.
func (l *barListener) OnFinish() {
	l.bar.SetTotal(-1, true)
}
