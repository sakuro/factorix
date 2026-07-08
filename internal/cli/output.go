package cli

import (
	"fmt"
	"io"
	"os"

	"github.com/fatih/color"
)

// printer renders user-facing messages with the emoji prefixes and colors
// shared with the Ruby implementation.
type printer struct {
	out   io.Writer
	quiet bool
}

// colorEnabled matches the Ruby color? check exactly: NO_COLOR only
// disables color when set to a non-empty value: an unset or empty NO_COLOR
// leaves color on. This deliberately ignores TTY status — Ruby's tint_me
// has no such check — so behavior does not depend on the writer in use
// (tests write to a bytes.Buffer, not a terminal).
func colorEnabled() bool {
	return os.Getenv("NO_COLOR") == ""
}

// newStyle builds a Color explicitly pinned to colorEnabled(), independent
// of fatih/color's package-level NoColor (which mixes in TTY detection on
// os.Stdout regardless of the writer actually used).
func newStyle(attrs ...color.Attribute) *color.Color {
	c := color.New(attrs...)
	if colorEnabled() {
		c.EnableColor()
	} else {
		c.DisableColor()
	}
	return c
}

func styleSuccess() *color.Color { return newStyle(color.FgGreen) }
func styleInfo() *color.Color    { return newStyle(color.FgCyan) }
func styleWarn() *color.Color    { return newStyle(color.FgMagenta) }
func styleError() *color.Color   { return newStyle(color.FgRed) }

// Println writes data output; it is never suppressed by --quiet.
func (p *printer) Println(a ...any) {
	fmt.Fprintln(p.out, a...)
}

// Printf writes data output; it is never suppressed by --quiet.
func (p *printer) Printf(format string, a ...any) {
	fmt.Fprintf(p.out, format, a...)
}

// say writes a decorated message unless --quiet is in effect.
func (p *printer) say(style *color.Color, prefix, message string) {
	if p.quiet {
		return
	}
	line := message
	if prefix != "" {
		line = prefix + " " + message
	}
	style.Fprintln(p.out, line)
}

// Say writes an undecorated message unless --quiet is in effect.
func (p *printer) Say(message string) {
	if p.quiet {
		return
	}
	fmt.Fprintln(p.out, message)
}

func (p *printer) Success(message string) {
	p.say(styleSuccess(), "✓", message)
}

func (p *printer) Info(message string) {
	p.say(styleInfo(), "ℹ", message)
}

func (p *printer) Warn(message string) {
	p.say(styleWarn(), "⚠︎", message)
}

func (p *printer) Error(message string) {
	p.say(styleError(), "✗", message)
}
