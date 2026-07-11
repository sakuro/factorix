// Package save extracts MOD information and startup settings from Factorio
// save files (.zip archives containing level.dat0 or level-init.dat).
//
// This lives outside internal/mod because it needs internal/serdes, which
// itself imports internal/mod for the version types.
package save

import (
	"archive/zip"
	"bufio"
	"compress/zlib"
	"io"
	"strings"

	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/serdes"
	"github.com/sakuro/factorix/internal/settings"
)

// Level file names to search for, in priority order.
var levelFileNames = []string{"level.dat0", "level-init.dat"}

// File is the information extracted from a save file.
type File struct {
	Version         mod.GameVersion
	MODs            []MODEntry // in save-file order; every recorded MOD is enabled
	StartupSettings *settings.Section
}

// MODEntry is one MOD recorded in the save header.
type MODEntry struct {
	Name    string
	Version mod.MODVersion
}

// Load extracts MOD information and startup settings from a save file.
func Load(path string) (*File, error) {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return nil, &mod.FileFormatError{Path: path, Msg: "invalid zip file: " + err.Error()}
	}
	defer zr.Close()

	for _, fileName := range levelFileNames {
		entry := findLevelEntry(&zr.Reader, fileName)
		if entry == nil {
			continue
		}
		rc, err := entry.Open()
		if err != nil {
			return nil, &mod.FileFormatError{Path: path, Msg: err.Error()}
		}
		defer rc.Close()

		r, err := decompressIfNeeded(rc)
		if err != nil {
			return nil, &mod.FileFormatError{Path: path, Msg: err.Error()}
		}
		return parse(r)
	}
	return nil, &mod.FileFormatError{Path: path, Msg: "level.dat0 or level-init.dat not found"}
}

// The level file sits in the single top-level directory named after the save.
func findLevelEntry(zr *zip.Reader, fileName string) *zip.File {
	for _, f := range zr.File {
		parts := strings.Split(f.Name, "/")
		if len(parts) == 2 && parts[1] == fileName {
			return f
		}
	}
	return nil
}

// decompressIfNeeded wraps r with a zlib reader when the content is
// compressed. CMF byte 0x78 marks zlib (DEFLATE with a 32K window).
func decompressIfNeeded(r io.Reader) (io.Reader, error) {
	br := bufio.NewReader(r)
	head, err := br.Peek(1)
	if err != nil {
		if err == io.EOF {
			return br, nil
		}
		return nil, err
	}
	if head[0] == 0x78 {
		return zlib.NewReader(br)
	}
	return br, nil
}

// headerReader reads consecutive header fields with a sticky error, so the
// field sequence below stays readable.
type headerReader struct {
	d   *serdes.Deserializer
	err error
}

// u8, u32, and boolean currently have no call site that keeps their
// result — the header fields they read are skipped, not interpreted — but
// they return a value to stay symmetric with u16/gameVersion/modVersion/str,
// which do. Splitting the API into "value" and "skip" variants would read
// worse than the occasional discarded return.
//
//nolint:unparam
func (h *headerReader) u8() uint8 {
	var v uint8
	if h.err == nil {
		v, h.err = h.d.ReadU8()
	}
	return v
}

func (h *headerReader) u16() uint16 {
	var v uint16
	if h.err == nil {
		v, h.err = h.d.ReadU16()
	}
	return v
}

//nolint:unparam // see u8
func (h *headerReader) u32() uint32 {
	var v uint32
	if h.err == nil {
		v, h.err = h.d.ReadU32()
	}
	return v
}

func (h *headerReader) optimU32() uint32 {
	var v uint32
	if h.err == nil {
		v, h.err = h.d.ReadOptimU32()
	}
	return v
}

//nolint:unparam // see u8
func (h *headerReader) boolean() bool {
	var v bool
	if h.err == nil {
		v, h.err = h.d.ReadBool()
	}
	return v
}

func (h *headerReader) str() string {
	var v string
	if h.err == nil {
		v, h.err = h.d.ReadStr()
	}
	return v
}

func (h *headerReader) gameVersion() mod.GameVersion {
	var v mod.GameVersion
	if h.err == nil {
		v, h.err = h.d.ReadGameVersion()
	}
	return v
}

func (h *headerReader) modVersion() mod.MODVersion {
	var v mod.MODVersion
	if h.err == nil {
		v, h.err = h.d.ReadMODVersion()
	}
	return v
}

func parse(r io.Reader) (*File, error) {
	d := serdes.NewDeserializer(r)
	h := &headerReader{d: d}

	version := h.gameVersion()

	h.u8()         // unknown byte after the version
	h.str()        // campaign
	h.str()        // level_name
	h.str()        // base_mod
	h.u8()         // difficulty
	h.boolean()    // finished
	h.boolean()    // player_won
	h.str()        // next_level
	h.boolean()    // can_continue
	h.boolean()    // finished_but_continuing
	h.boolean()    // saving_replay
	h.boolean()    // allow_non_admin_debug_options
	h.modVersion() // loaded_from (MODVersion, not GameVersion)
	h.u16()        // loaded_from_build
	h.u8()         // allowed_commands
	h.boolean()    // unknown
	h.u32()        // unknown
	h.boolean()    // unknown

	modsCount := h.optimU32()
	var mods []MODEntry
	for range modsCount {
		name := h.str()
		modVersion := h.modVersion()
		h.u32() // CRC
		if h.err != nil {
			return nil, h.err
		}
		mods = append(mods, MODEntry{Name: name, Version: modVersion})
	}

	// Unknown 4 bytes between the MOD list and the startup settings.
	h.u32()
	if h.err != nil {
		return nil, h.err
	}

	startup, err := parseStartupSettings(d)
	if err != nil {
		return nil, err
	}

	return &File{Version: version, MODs: mods, StartupSettings: startup}, nil
}

func parseStartupSettings(d *serdes.Deserializer) (*settings.Section, error) {
	tree, err := d.ReadPropertyTree()
	if err != nil {
		return nil, err
	}

	section, err := settings.NewSection("startup")
	if err != nil {
		return nil, err
	}

	// Non-dictionary elements are skipped, as in the Ruby implementation:
	// each setting is expected to be a {"value": X} dictionary.
	entries, ok := tree.Dict()
	if !ok {
		return section, nil
	}
	for _, entry := range entries {
		wrapper, ok := entry.Value.Dict()
		if !ok {
			continue
		}
		for _, wrapperEntry := range wrapper {
			if wrapperEntry.Key == "value" {
				section.Set(entry.Key, wrapperEntry.Value)
				break
			}
		}
	}
	return section, nil
}
