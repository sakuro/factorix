package mod

import (
	"cmp"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Form is the on-disk shape of an installed MOD package.
type Form int

const (
	FormZIP Form = iota
	FormDirectory
)

func (f Form) String() string {
	switch f {
	case FormZIP:
		return "zip"
	case FormDirectory:
		return "directory"
	default:
		return fmt.Sprintf("Form(%d)", int(f))
	}
}

// InstalledMOD is an actual MOD package found in the MOD directory or the
// data directory, as opposed to MOD (a name) and MODState (desired state in
// mod-list.json).
type InstalledMOD struct {
	MOD     MOD
	Version MODVersion
	Form    Form
	Path    string
	Info    InfoJSON
}

// versionSegmentMatches reports whether s names the same version as v. It
// parses s rather than comparing rendered strings, so on-disk names that use
// a non-canonical version format (e.g. a MOD Portal release zero-padded as
// "0.1.01") still match the canonical "0.1.1" declared in info.json.
func versionSegmentMatches(s string, v MODVersion) bool {
	parsed, err := ParseMODVersion(s)
	return err == nil && parsed.Compare(v) == 0
}

// InstalledMODFromZIP loads an installed MOD from a ZIP file.
// The filename must be "<name>_<version>.zip".
func InstalledMODFromZIP(path string) (InstalledMOD, error) {
	info, err := InfoJSONFromZIP(path)
	if err != nil {
		return InstalledMOD{}, err
	}

	actual := filepath.Base(path)
	rest, hasPrefix := strings.CutPrefix(actual, info.Name+"_")
	versionSegment, hasSuffix := strings.CutSuffix(rest, ".zip")
	if !hasPrefix || !hasSuffix || !versionSegmentMatches(versionSegment, info.Version) {
		return InstalledMOD{}, &FileFormatError{
			Path: path,
			Msg:  fmt.Sprintf("filename mismatch: expected %s_%s.zip, got %s", info.Name, info.Version, actual),
		}
	}

	return InstalledMOD{MOD: MOD{Name: info.Name}, Version: info.Version, Form: FormZIP, Path: path, Info: info}, nil
}

// InstalledMODFromDirectory loads an installed MOD from a directory.
// The directory must be named "<name>" or "<name>_<version>".
func InstalledMODFromDirectory(path string) (InstalledMOD, error) {
	data, err := os.ReadFile(filepath.Join(path, "info.json"))
	if err != nil {
		return InstalledMOD{}, &FileFormatError{Path: path, Msg: "missing info.json"}
	}

	info, err := ParseInfoJSON(data)
	if err != nil {
		return InstalledMOD{}, err
	}

	dirname := filepath.Base(path)
	versionSegment, hasPrefix := strings.CutPrefix(dirname, info.Name+"_")
	if dirname != info.Name && (!hasPrefix || !versionSegmentMatches(versionSegment, info.Version)) {
		return InstalledMOD{}, &FileFormatError{
			Path: path,
			Msg:  fmt.Sprintf("directory name mismatch: expected %s or %s_%s, got %s", info.Name, info.Name, info.Version, dirname),
		}
	}

	return InstalledMOD{MOD: MOD{Name: info.Name}, Version: info.Version, Form: FormDirectory, Path: path, Info: info}, nil
}

// IsBase reports whether this is the base MOD.
func (im InstalledMOD) IsBase() bool {
	return im.MOD.IsBase()
}

// IsExpansion reports whether this is an official expansion MOD.
func (im InstalledMOD) IsExpansion() bool {
	return im.MOD.IsExpansion()
}

// Compare orders by version, then by form. Only meaningful between packages
// of the same MOD.
func (im InstalledMOD) Compare(other InstalledMOD) int {
	if c := im.Version.Compare(other.Version); c != 0 {
		return c
	}
	return cmp.Compare(im.formPriority(), other.formPriority())
}

// A directory typically holds a development checkout, so it shadows a ZIP
// of the same name and version.
func (im InstalledMOD) formPriority() int {
	if im.Form == FormDirectory {
		return 1
	}
	return 0
}
