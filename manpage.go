// Package factorix embeds distribution assets that must travel inside the
// single binary.
package factorix

import _ "embed"

// ManPage is the roff source of the factorix(1) manual page.
//
//go:embed doc/factorix.1
var ManPage []byte
