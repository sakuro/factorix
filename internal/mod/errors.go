package mod

import (
	"errors"
	"fmt"
)

// Sentinel errors for MOD list operations.
var (
	ErrMODNotInList             = errors.New("MOD not in the list")
	ErrCannotDisableBaseMOD     = errors.New("cannot disable the base MOD")
	ErrCannotRemoveBaseMOD      = errors.New("cannot remove the base MOD")
	ErrCannotRemoveExpansionMOD = errors.New("cannot remove an expansion MOD")
)

// VersionParseError reports a malformed or out-of-range version string.
type VersionParseError struct {
	Input string
}

func (e *VersionParseError) Error() string {
	return fmt.Sprintf("invalid version string: %q", e.Input)
}

// FileFormatError reports an invalid MOD package or metadata file.
type FileFormatError struct {
	Path string
	Msg  string
}

func (e *FileFormatError) Error() string {
	if e.Path == "" {
		return e.Msg
	}
	return fmt.Sprintf("%s: %s", e.Path, e.Msg)
}
