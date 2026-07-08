// Package settings handles MOD settings stored in mod-settings.dat.
package settings

import (
	"fmt"
	"iter"
	"slices"

	"github.com/sakuro/factorix/internal/serdes"
)

// ValidSections lists the three section names of mod-settings.dat.
var ValidSections = []string{"startup", "runtime-global", "runtime-per-user"}

// Section is one named group of settings. Keys keep their insertion order so
// a load-and-save round trip preserves file order.
type Section struct {
	name   string
	keys   []string
	values map[string]serdes.PropertyTree
}

// NewSection creates an empty section with one of the ValidSections names.
func NewSection(name string) (*Section, error) {
	if !slices.Contains(ValidSections, name) {
		return nil, fmt.Errorf("%w: %s", ErrInvalidSectionName, name)
	}
	return &Section{name: name, values: map[string]serdes.PropertyTree{}}, nil
}

// Name returns the section name.
func (s *Section) Name() string {
	return s.name
}

// Len returns the number of settings in the section.
func (s *Section) Len() int {
	return len(s.keys)
}

// Get returns the value for key; ok is false when the key is absent.
func (s *Section) Get(key string) (serdes.PropertyTree, bool) {
	v, ok := s.values[key]
	return v, ok
}

// Set stores the value for key, appending new keys in insertion order.
func (s *Section) Set(key string, value serdes.PropertyTree) {
	if _, ok := s.values[key]; !ok {
		s.keys = append(s.keys, key)
	}
	s.values[key] = value
}

// All iterates over key/value pairs in insertion order.
func (s *Section) All() iter.Seq2[string, serdes.PropertyTree] {
	return func(yield func(string, serdes.PropertyTree) bool) {
		for _, key := range s.keys {
			if !yield(key, s.values[key]) {
				return
			}
		}
	}
}
