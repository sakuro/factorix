package mod

import (
	"bytes"
	"encoding/json"
	"fmt"
	"iter"
	"os"
	"slices"
)

// MODList manages mod-list.json: the set of MODs and their enabled state.
// Entries keep their insertion order, matching how Factorio writes the file.
type MODList struct {
	order  []MOD
	states map[MOD]MODState
}

type modListJSON struct {
	Mods []modEntryJSON `json:"mods"`
}

type modEntryJSON struct {
	Name    string `json:"name"`
	Enabled bool   `json:"enabled"`
	Version string `json:"version,omitempty"`
}

// NewMODList returns an empty MOD list.
func NewMODList() *MODList {
	return &MODList{states: map[MOD]MODState{}}
}

// LoadMODList reads a mod-list.json file.
func LoadMODList(path string) (*MODList, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var raw modListJSON
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, &FileFormatError{Path: path, Msg: err.Error()}
	}

	list := NewMODList()
	for _, entry := range raw.Mods {
		var version *MODVersion
		if entry.Version != "" {
			v, err := ParseMODVersion(entry.Version)
			if err != nil {
				return nil, &FileFormatError{Path: path, Msg: err.Error()}
			}
			version = &v
		}
		if err := list.Add(MOD{Name: entry.Name}, MODState{Enabled: entry.Enabled, Version: version}); err != nil {
			return nil, err
		}
	}
	return list, nil
}

// Save writes the list to a mod-list.json file.
func (l *MODList) Save(path string) error {
	doc := modListJSON{Mods: make([]modEntryJSON, 0, len(l.order))}
	for _, m := range l.order {
		state := l.states[m]
		entry := modEntryJSON{Name: m.Name, Enabled: state.Enabled}
		if state.Version != nil {
			entry.Version = state.Version.String()
		}
		doc.Mods = append(doc.Mods, entry)
	}

	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(doc); err != nil {
		return err
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

// Len returns the number of entries.
func (l *MODList) Len() int {
	return len(l.order)
}

// Contains reports whether the MOD is in the list.
func (l *MODList) Contains(m MOD) bool {
	_, ok := l.states[m]
	return ok
}

// Add inserts the MOD with the given state, or replaces its state if already present.
func (l *MODList) Add(m MOD, state MODState) error {
	if m.IsBase() && !state.Enabled {
		return ErrCannotDisableBaseMOD
	}

	if !l.Contains(m) {
		l.order = append(l.order, m)
	}
	l.states[m] = state
	return nil
}

// Remove deletes the MOD from the list. Removing a MOD that is not in the
// list is a no-op.
func (l *MODList) Remove(m MOD) error {
	if m.IsBase() {
		return ErrCannotRemoveBaseMOD
	}
	if m.IsExpansion() {
		return fmt.Errorf("%w: %s", ErrCannotRemoveExpansionMOD, m)
	}

	if !l.Contains(m) {
		return nil
	}
	delete(l.states, m)
	l.order = slices.DeleteFunc(l.order, func(x MOD) bool { return x == m })
	return nil
}

// Enabled reports whether the MOD is enabled.
func (l *MODList) Enabled(m MOD) (bool, error) {
	state, ok := l.states[m]
	if !ok {
		return false, fmt.Errorf("%w: %s", ErrMODNotInList, m)
	}
	return state.Enabled, nil
}

// Version returns the MOD's version, or nil when not specified.
func (l *MODList) Version(m MOD) (*MODVersion, error) {
	state, ok := l.states[m]
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrMODNotInList, m)
	}
	return state.Version, nil
}

// Enable marks the MOD as enabled, keeping its version.
func (l *MODList) Enable(m MOD) error {
	state, ok := l.states[m]
	if !ok {
		return fmt.Errorf("%w: %s", ErrMODNotInList, m)
	}
	state.Enabled = true
	l.states[m] = state
	return nil
}

// Disable marks the MOD as disabled, keeping its version.
func (l *MODList) Disable(m MOD) error {
	if m.IsBase() {
		return ErrCannotDisableBaseMOD
	}
	state, ok := l.states[m]
	if !ok {
		return fmt.Errorf("%w: %s", ErrMODNotInList, m)
	}
	state.Enabled = false
	l.states[m] = state
	return nil
}

// All iterates over MOD/state pairs in insertion order.
func (l *MODList) All() iter.Seq2[MOD, MODState] {
	return func(yield func(MOD, MODState) bool) {
		for _, m := range l.order {
			if !yield(m, l.states[m]) {
				return
			}
		}
	}
}

// MODs iterates over MODs in insertion order.
func (l *MODList) MODs() iter.Seq[MOD] {
	return func(yield func(MOD) bool) {
		for _, m := range l.order {
			if !yield(m) {
				return
			}
		}
	}
}
