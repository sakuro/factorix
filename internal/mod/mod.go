// Package mod holds the core domain types: MOD identity, versions,
// mod-list.json handling, and installed MOD packages.
package mod

import "strings"

// MOD identifies a MOD by name.
type MOD struct {
	Name string
}

var expansionMODs = map[string]bool{
	"space-age":      true,
	"quality":        true,
	"elevated-rails": true,
}

// IsBase reports whether this is the base MOD.
// The check is case-sensitive: only "base" qualifies.
func (m MOD) IsBase() bool {
	return m.Name == "base"
}

// IsExpansion reports whether this is an official expansion MOD
// (space-age, quality, or elevated-rails). The check is case-sensitive.
func (m MOD) IsExpansion() bool {
	return expansionMODs[m.Name]
}

func (m MOD) String() string {
	return m.Name
}

// Compare orders MODs by name, except that the base MOD is ordered before
// any other MOD.
func (m MOD) Compare(other MOD) int {
	switch {
	case m.IsBase() && other.IsBase():
		return 0
	case m.IsBase():
		return -1
	case other.IsBase():
		return 1
	default:
		return strings.Compare(m.Name, other.Name)
	}
}
