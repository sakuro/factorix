package mod

import (
	"archive/zip"
	"encoding/json"
	"io"
	"strings"
)

// InfoJSON is the metadata file present in every Factorio MOD.
// Only the required fields (name, version, title, author) are enforced.
//
// See https://lua-api.factorio.com/latest/auxiliary/mod-structure.html
type InfoJSON struct {
	Name            string
	Version         MODVersion
	Title           string
	Author          string
	Description     string
	FactorioVersion string
	Dependencies    []string // raw dependency strings; parsing arrives with internal/dependency
}

// Pointer fields distinguish absent required fields from empty strings.
type infoJSONRaw struct {
	Name            *string  `json:"name"`
	Version         *string  `json:"version"`
	Title           *string  `json:"title"`
	Author          *string  `json:"author"`
	Description     string   `json:"description"`
	FactorioVersion string   `json:"factorio_version"`
	Dependencies    []string `json:"dependencies"`
}

// ParseInfoJSON parses info.json content.
func ParseInfoJSON(data []byte) (InfoJSON, error) {
	var raw infoJSONRaw
	if err := json.Unmarshal(data, &raw); err != nil {
		return InfoJSON{}, &FileFormatError{Msg: "invalid JSON: " + err.Error()}
	}

	var missing []string
	for _, field := range []struct {
		name  string
		value *string
	}{
		{"name", raw.Name},
		{"version", raw.Version},
		{"title", raw.Title},
		{"author", raw.Author},
	} {
		if field.value == nil {
			missing = append(missing, field.name)
		}
	}
	if len(missing) > 0 {
		return InfoJSON{}, &FileFormatError{Msg: "missing required fields: " + strings.Join(missing, ", ")}
	}

	version, err := ParseMODVersion(*raw.Version)
	if err != nil {
		return InfoJSON{}, &FileFormatError{Msg: err.Error()}
	}

	return InfoJSON{
		Name:            *raw.Name,
		Version:         version,
		Title:           *raw.Title,
		Author:          *raw.Author,
		Description:     raw.Description,
		FactorioVersion: raw.FactorioVersion,
		Dependencies:    raw.Dependencies,
	}, nil
}

// InfoJSONFromZIP extracts and parses info.json from a MOD ZIP file.
func InfoJSONFromZIP(path string) (InfoJSON, error) {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return InfoJSON{}, &FileFormatError{Path: path, Msg: "invalid zip file: " + err.Error()}
	}
	defer zr.Close()

	// MOD ZIPs contain a single top-level directory, so info.json always
	// sits below it — hence the "/info.json" suffix match.
	for _, f := range zr.File {
		if !strings.HasSuffix(f.Name, "/info.json") {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return InfoJSON{}, &FileFormatError{Path: path, Msg: err.Error()}
		}
		data, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			return InfoJSON{}, &FileFormatError{Path: path, Msg: err.Error()}
		}
		return ParseInfoJSON(data)
	}
	return InfoJSON{}, &FileFormatError{Path: path, Msg: "info.json not found"}
}
