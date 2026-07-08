package cli

import (
	"bytes"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

// clearNoColor removes NO_COLOR from the process environment for the
// duration of the test, since os.Getenv can't distinguish "unset" from a
// value set by an earlier t.Setenv in the same test binary otherwise.
func clearNoColor(t *testing.T) {
	t.Helper()
	t.Setenv("NO_COLOR", "")
	// t.Setenv("NO_COLOR", "") makes it present-but-empty, not absent. Both
	// must enable color per colorEnabled's contract, so this covers the
	// "absent" case adequately for what colorEnabled can observe.
}

func TestColorEnabled(t *testing.T) {
	tests := map[string]bool{
		"":  true,  // unset or empty: color stays on
		"1": false, // any non-empty value disables color
		"0": false, // including "0" — the convention is presence, not truthiness
	}
	for value, want := range tests {
		t.Run("NO_COLOR="+value, func(t *testing.T) {
			t.Setenv("NO_COLOR", value)
			assert.Equal(t, want, colorEnabled())
		})
	}
}

func TestPrinterRespectsNoColor(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	var buf bytes.Buffer
	p := &printer{out: &buf}
	p.Success("done")
	assert.Equal(t, "✓ done\n", buf.String())
	assert.False(t, strings.Contains(buf.String(), "\x1b["))
}

func TestPrinterAppliesColorWhenEnabled(t *testing.T) {
	clearNoColor(t)
	var buf bytes.Buffer
	p := &printer{out: &buf}
	p.Success("done")
	// The decoration and text survive regardless of ANSI wrapping; whether
	// ANSI codes appear depends only on NO_COLOR (colorEnabled), never on
	// the writer's TTY status, which is the behavior being locked in here.
	assert.Contains(t, buf.String(), "done")
	assert.True(t, strings.Contains(buf.String(), "\x1b["), "expected ANSI codes when NO_COLOR is unset")
}

func TestPrinterQuietSuppressesDecoratedMessages(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	var buf bytes.Buffer
	p := &printer{out: &buf, quiet: true}
	p.Success("done")
	p.Info("info")
	p.Warn("warn")
	p.Error("error")
	p.Say("plain")
	assert.Empty(t, buf.String())
}

func TestPrinterDataOutputIgnoresQuiet(t *testing.T) {
	var buf bytes.Buffer
	p := &printer{out: &buf, quiet: true}
	p.Println("data")
	assert.Equal(t, "data\n", buf.String())
}
