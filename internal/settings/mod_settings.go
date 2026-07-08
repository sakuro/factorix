package settings

import (
	"fmt"
	"io"
	"iter"
	"os"
	"slices"

	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/serdes"
)

// MODSettings is the content of mod-settings.dat: a game version and the
// three settings sections.
type MODSettings struct {
	GameVersion mod.GameVersion
	order       []string
	sections    map[string]*Section
}

// New returns MODSettings with all three sections empty, in canonical order.
func New(version mod.GameVersion) *MODSettings {
	ms := &MODSettings{GameVersion: version, sections: map[string]*Section{}}
	for _, name := range ValidSections {
		section, _ := NewSection(name)
		ms.order = append(ms.order, name)
		ms.sections[name] = section
	}
	return ms
}

// Load reads mod-settings.dat content from r.
func Load(r io.Reader) (*MODSettings, error) {
	d := serdes.NewDeserializer(r)

	version, err := d.ReadGameVersion()
	if err != nil {
		return nil, err
	}
	// One boolean of unknown purpose follows the version; always false.
	if _, err := d.ReadBool(); err != nil {
		return nil, err
	}

	tree, err := d.ReadPropertyTree()
	if err != nil {
		return nil, err
	}
	sections, ok := tree.Dict()
	if !ok {
		return nil, fmt.Errorf("%w: top-level element is not a dictionary", ErrMalformedSettings)
	}

	ms := &MODSettings{GameVersion: version, sections: map[string]*Section{}}
	for _, sectionEntry := range sections {
		section, err := NewSection(sectionEntry.Key)
		if err != nil {
			return nil, err
		}
		settingEntries, ok := sectionEntry.Value.Dict()
		if !ok {
			return nil, fmt.Errorf("%w: section %q is not a dictionary", ErrMalformedSettings, sectionEntry.Key)
		}
		for _, settingEntry := range settingEntries {
			value, err := unwrapValue(settingEntry)
			if err != nil {
				return nil, err
			}
			section.Set(settingEntry.Key, value)
		}
		ms.order = append(ms.order, section.Name())
		ms.sections[section.Name()] = section
	}

	// Sections absent from the file still exist, empty, in canonical order.
	for _, name := range ValidSections {
		if _, ok := ms.sections[name]; !ok {
			section, _ := NewSection(name)
			ms.order = append(ms.order, name)
			ms.sections[name] = section
		}
	}

	var trailing [1]byte
	if n, _ := io.ReadFull(r, trailing[:]); n > 0 {
		return nil, ErrExtraData
	}

	return ms, nil
}

// LoadFile reads a mod-settings.dat file.
func LoadFile(path string) (*MODSettings, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return Load(f)
}

// Each setting is stored as a one-entry dictionary {"value": X}.
func unwrapValue(settingEntry serdes.DictEntry) (serdes.PropertyTree, error) {
	wrapper, ok := settingEntry.Value.Dict()
	if !ok {
		return serdes.PropertyTree{}, fmt.Errorf("%w: setting %q is not a dictionary", ErrMalformedSettings, settingEntry.Key)
	}
	for _, entry := range wrapper {
		if entry.Key == "value" {
			return entry.Value, nil
		}
	}
	return serdes.PropertyTree{}, fmt.Errorf("%w: setting %q has no value entry", ErrMalformedSettings, settingEntry.Key)
}

// Save writes mod-settings.dat content to w. Empty sections are omitted,
// matching the Ruby implementation.
func (ms *MODSettings) Save(w io.Writer) error {
	s := serdes.NewSerializer(w)

	if err := s.WriteGameVersion(ms.GameVersion); err != nil {
		return err
	}
	if err := s.WriteBool(false); err != nil {
		return err
	}

	var sections []serdes.DictEntry
	for _, name := range ms.order {
		section := ms.sections[name]
		if section.Len() == 0 {
			continue
		}
		var settingEntries []serdes.DictEntry
		for key, value := range section.All() {
			settingEntries = append(settingEntries, serdes.DictEntry{
				Key:   key,
				Value: serdes.Dict(serdes.DictEntry{Key: "value", Value: value}),
			})
		}
		sections = append(sections, serdes.DictEntry{Key: name, Value: serdes.Dict(settingEntries...)})
	}
	return s.WritePropertyTree(serdes.Dict(sections...))
}

// SaveFile writes a mod-settings.dat file.
func (ms *MODSettings) SaveFile(path string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return ms.Save(f)
}

// Section returns the named section.
func (ms *MODSettings) Section(name string) (*Section, error) {
	if !slices.Contains(ValidSections, name) {
		return nil, fmt.Errorf("%w: %s", ErrInvalidSectionName, name)
	}
	section, ok := ms.sections[name]
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrSectionNotFound, name)
	}
	return section, nil
}

// Sections iterates over the sections in order.
func (ms *MODSettings) Sections() iter.Seq[*Section] {
	return func(yield func(*Section) bool) {
		for _, name := range ms.order {
			if !yield(ms.sections[name]) {
				return
			}
		}
	}
}
