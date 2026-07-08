package mod

import (
	"cmp"
	"fmt"
	"regexp"
	"strconv"
)

// GameVersion is Factorio's 4-component game version (major.minor.patch-build),
// stored as 4 x 16-bit unsigned integers.
//
// See https://wiki.factorio.com/Version_string_format
type GameVersion struct {
	Major uint16
	Minor uint16
	Patch uint16
	Build uint16
}

var gameVersionRE = regexp.MustCompile(`\A(\d+)\.(\d+)\.(\d+)(?:-(\d+))?\z`)

// ParseGameVersion parses a version string in "X.Y.Z-B" or "X.Y.Z" format
// (build defaults to 0 when omitted).
func ParseGameVersion(s string) (GameVersion, error) {
	m := gameVersionRE.FindStringSubmatch(s)
	if m == nil {
		return GameVersion{}, &VersionParseError{Input: s}
	}

	var parts [4]uint16
	for i, digits := range m[1:] {
		if digits == "" {
			break
		}
		n, err := strconv.ParseUint(digits, 10, 16)
		if err != nil {
			return GameVersion{}, &VersionParseError{Input: s}
		}
		parts[i] = uint16(n)
	}
	return GameVersion{Major: parts[0], Minor: parts[1], Patch: parts[2], Build: parts[3]}, nil
}

// String renders "X.Y.Z-B", omitting "-B" when the build is 0.
func (v GameVersion) String() string {
	if v.Build == 0 {
		return fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch)
	}
	return fmt.Sprintf("%d.%d.%d-%d", v.Major, v.Minor, v.Patch, v.Build)
}

// Compare returns -1, 0, or 1 depending on whether v is ordered before,
// equal to, or after other.
func (v GameVersion) Compare(other GameVersion) int {
	if c := cmp.Compare(v.Major, other.Major); c != 0 {
		return c
	}
	if c := cmp.Compare(v.Minor, other.Minor); c != 0 {
		return c
	}
	if c := cmp.Compare(v.Patch, other.Patch); c != 0 {
		return c
	}
	return cmp.Compare(v.Build, other.Build)
}

// Less reports whether v is ordered before other.
func (v GameVersion) Less(other GameVersion) bool {
	return v.Compare(other) < 0
}
