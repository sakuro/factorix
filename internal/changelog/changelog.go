// Package changelog parses and manipulates Factorio changelog.txt files.
//
// See https://wiki.factorio.com/Tutorial:Mod_changelog_format
package changelog

import (
	"errors"
	"fmt"
	"os"
	"slices"
	"strings"

	"github.com/sakuro/factorix/internal/mod"
)

// Separator is the section separator line (99 dashes).
var Separator = strings.Repeat("-", 99)

// Unreleased is the version label of the unreleased section.
const Unreleased = "Unreleased"

var (
	ErrParse            = errors.New("invalid changelog")
	ErrInvalidArgument  = errors.New("invalid argument")
	ErrInvalidOperation = errors.New("invalid operation")
)

// Category is one named group of entries within a section, in file order.
type Category struct {
	Name    string
	Entries []string // multi-line entries contain "\n"
}

// Section is one version block of the changelog. A nil Version marks the
// Unreleased section.
type Section struct {
	Version    *mod.MODVersion
	Date       string
	Categories []Category
}

// VersionLabel renders the version as it appears in the file.
func (s *Section) VersionLabel() string {
	if s.Version == nil {
		return Unreleased
	}
	return s.Version.String()
}

func (s *Section) matches(version *mod.MODVersion) bool {
	if version == nil || s.Version == nil {
		return version == nil && s.Version == nil
	}
	return *s.Version == *version
}

func (s *Section) category(name string) *Category {
	for i := range s.Categories {
		if s.Categories[i].Name == name {
			return &s.Categories[i]
		}
	}
	return nil
}

// Changelog is an ordered list of sections, newest first.
type Changelog struct {
	sections []*Section
}

// New returns an empty changelog.
func New() *Changelog {
	return &Changelog{}
}

// Sections returns the sections, newest first.
func (c *Changelog) Sections() []*Section {
	return c.sections
}

// FindSection returns the section for the version (nil = Unreleased).
func (c *Changelog) FindSection(version *mod.MODVersion) (*Section, bool) {
	for _, section := range c.sections {
		if section.matches(version) {
			return section, true
		}
	}
	return nil, false
}

// AddEntry appends an entry to the category of the version's section
// (nil = Unreleased), creating the section at the top and the category at
// the end as needed. Blank and duplicate entries are rejected.
func (c *Changelog) AddEntry(version *mod.MODVersion, categoryName, entry string) error {
	if strings.TrimSpace(entry) == "" {
		return fmt.Errorf("%w: entry must not be blank", ErrInvalidArgument)
	}

	section, ok := c.FindSection(version)
	if !ok {
		section = &Section{Version: version}
		c.sections = append([]*Section{section}, c.sections...)
	}

	category := section.category(categoryName)
	if category == nil {
		section.Categories = append(section.Categories, Category{Name: categoryName})
		category = &section.Categories[len(section.Categories)-1]
	}
	if slices.Contains(category.Entries, entry) {
		return fmt.Errorf("%w: duplicate entry: %s", ErrInvalidArgument, entry)
	}
	category.Entries = append(category.Entries, entry)
	return nil
}

// ReleaseSection turns the leading Unreleased section into a released one
// with the given version and date.
func (c *Changelog) ReleaseSection(version mod.MODVersion, date string) error {
	if len(c.sections) == 0 || c.sections[0].Version != nil {
		return fmt.Errorf("%w: first section is not %s", ErrInvalidOperation, Unreleased)
	}
	if _, ok := c.FindSection(&version); ok {
		return fmt.Errorf("%w: version %s already exists", ErrInvalidOperation, version)
	}
	c.sections[0].Version = &version
	c.sections[0].Date = date
	return nil
}

// String renders the changelog in the changelog.txt format.
func (c *Changelog) String() string {
	var b strings.Builder
	for i, section := range c.sections {
		if i > 0 {
			b.WriteString("\n")
		}
		b.WriteString(Separator + "\n")
		b.WriteString(formatSection(section))
	}
	b.WriteString("\n")
	return b.String()
}

func formatSection(section *Section) string {
	var lines []string
	lines = append(lines, "Version: "+section.VersionLabel())
	if section.Date != "" {
		lines = append(lines, "Date: "+section.Date)
	}
	for _, category := range section.Categories {
		lines = append(lines, "  "+category.Name+":")
		for _, entry := range category.Entries {
			entryLines := strings.Split(entry, "\n")
			lines = append(lines, "    - "+entryLines[0])
			for _, continuation := range entryLines[1:] {
				lines = append(lines, "      "+continuation)
			}
		}
	}
	return strings.Join(lines, "\n")
}

// Load reads a changelog file; a missing file yields an empty changelog.
func Load(path string) (*Changelog, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return New(), nil
		}
		return nil, err
	}
	return Parse(string(data))
}

// Save writes the changelog to a file.
func (c *Changelog) Save(path string) error {
	return os.WriteFile(path, []byte(c.String()), 0o644)
}

// parser walks the changelog line by line.
type parser struct {
	lines []string
	pos   int
}

// Parse parses changelog.txt content.
func Parse(text string) (*Changelog, error) {
	// Normalize CRLF; the writer always emits LF.
	text = strings.ReplaceAll(text, "\r\n", "\n")
	p := &parser{lines: strings.Split(text, "\n")}
	// strings.Split leaves a trailing empty element for text ending in \n.
	if n := len(p.lines); n > 0 && p.lines[n-1] == "" {
		p.lines = p.lines[:n-1]
	}

	var sections []*Section
	for !p.done() {
		section, err := p.parseSection()
		if err != nil {
			return nil, err
		}
		sections = append(sections, section)
	}
	if len(sections) == 0 {
		return nil, fmt.Errorf("%w: no sections found", ErrParse)
	}
	return &Changelog{sections: sections}, nil
}

func (p *parser) done() bool {
	return p.pos >= len(p.lines)
}

func (p *parser) peek() string {
	return p.lines[p.pos]
}

func (p *parser) next() string {
	line := p.lines[p.pos]
	p.pos++
	return line
}

func (p *parser) parseSection() (*Section, error) {
	if p.done() || p.peek() != Separator {
		return nil, fmt.Errorf("%w: line %d: expected separator", ErrParse, p.pos+1)
	}
	p.next()

	if p.done() || !strings.HasPrefix(p.peek(), "Version: ") {
		return nil, fmt.Errorf("%w: line %d: expected \"Version: \"", ErrParse, p.pos+1)
	}
	versionText := strings.TrimSpace(strings.TrimPrefix(p.next(), "Version: "))
	section := &Section{}
	if !strings.EqualFold(versionText, Unreleased) {
		version, err := mod.ParseMODVersion(versionText)
		if err != nil {
			return nil, fmt.Errorf("%w: line %d: %s", ErrParse, p.pos, err)
		}
		section.Version = &version
	}

	if !p.done() && strings.HasPrefix(p.peek(), "Date: ") {
		section.Date = strings.TrimSpace(strings.TrimPrefix(p.next(), "Date: "))
	}

	p.skipBlankLines()
	for !p.done() && strings.HasPrefix(p.peek(), "  ") && strings.HasSuffix(p.peek(), ":") && !strings.HasPrefix(p.peek(), "    ") {
		category, err := p.parseCategory()
		if err != nil {
			return nil, err
		}
		section.Categories = append(section.Categories, *category)
	}
	p.skipBlankLines()
	return section, nil
}

func (p *parser) parseCategory() (*Category, error) {
	line := p.next()
	name := strings.TrimSuffix(strings.TrimPrefix(line, "  "), ":")
	if name == "" {
		return nil, fmt.Errorf("%w: line %d: empty category name", ErrParse, p.pos)
	}
	category := &Category{Name: name}

	for !p.done() && strings.HasPrefix(p.peek(), "    - ") {
		entryLines := []string{strings.TrimPrefix(p.next(), "    - ")}
		for !p.done() && strings.HasPrefix(p.peek(), "      ") {
			entryLines = append(entryLines, strings.TrimPrefix(p.next(), "      "))
		}
		category.Entries = append(category.Entries, strings.Join(entryLines, "\n"))
	}
	if len(category.Entries) == 0 {
		return nil, fmt.Errorf("%w: line %d: category %q has no entries", ErrParse, p.pos, name)
	}
	return category, nil
}

func (p *parser) skipBlankLines() {
	for !p.done() && strings.TrimSpace(p.peek()) == "" {
		p.next()
	}
}
