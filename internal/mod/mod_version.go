package mod

import (
	"cmp"
	"fmt"
	"regexp"
	"strconv"
)

// MODVersion is a 3-component MOD version (major.minor.patch). Each component
// is serialized as a space-optimized 16-bit unsigned integer in save files.
//
// See https://wiki.factorio.com/Version_string_format
type MODVersion struct {
	Major uint16
	Minor uint16
	Patch uint16
}

var modVersionRE = regexp.MustCompile(`\A(\d+)\.(\d+)(?:\.(\d+))?\z`)

// ParseMODVersion parses a version string in "X.Y.Z" or "X.Y" format
// (patch defaults to 0 when omitted).
func ParseMODVersion(s string) (MODVersion, error) {
	m := modVersionRE.FindStringSubmatch(s)
	if m == nil {
		return MODVersion{}, &VersionParseError{Input: s}
	}

	var parts [3]uint16
	for i, digits := range m[1:] {
		if digits == "" {
			break
		}
		n, err := strconv.ParseUint(digits, 10, 16)
		if err != nil {
			return MODVersion{}, &VersionParseError{Input: s}
		}
		parts[i] = uint16(n)
	}
	return MODVersion{Major: parts[0], Minor: parts[1], Patch: parts[2]}, nil
}

// String renders "X.Y.Z".
func (v MODVersion) String() string {
	return fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch)
}

// Compare returns -1, 0, or 1 depending on whether v is ordered before,
// equal to, or after other.
func (v MODVersion) Compare(other MODVersion) int {
	if c := cmp.Compare(v.Major, other.Major); c != 0 {
		return c
	}
	if c := cmp.Compare(v.Minor, other.Minor); c != 0 {
		return c
	}
	return cmp.Compare(v.Patch, other.Patch)
}

// Less reports whether v is ordered before other.
func (v MODVersion) Less(other MODVersion) bool {
	return v.Compare(other) < 0
}
