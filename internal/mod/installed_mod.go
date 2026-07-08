package mod

import (
	"cmp"
	"fmt"
	"os"
	"path/filepath"
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

// InstalledMODFromZIP loads an installed MOD from a ZIP file.
// The filename must be "<name>_<version>.zip".
func InstalledMODFromZIP(path string) (InstalledMOD, error) {
	info, err := InfoJSONFromZIP(path)
	if err != nil {
		return InstalledMOD{}, err
	}

	expected := fmt.Sprintf("%s_%s.zip", info.Name, info.Version)
	actual := filepath.Base(path)
	if actual != expected {
		return InstalledMOD{}, &FileFormatError{
			Path: path,
			Msg:  fmt.Sprintf("filename mismatch: expected %s, got %s", expected, actual),
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
	versioned := fmt.Sprintf("%s_%s", info.Name, info.Version)
	if dirname != info.Name && dirname != versioned {
		return InstalledMOD{}, &FileFormatError{
			Path: path,
			Msg:  fmt.Sprintf("directory name mismatch: expected %s or %s, got %s", info.Name, versioned, dirname),
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
