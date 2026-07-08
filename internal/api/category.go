package api

import "fmt"

// Category is a MOD Portal category's display information.
//
// See https://wiki.factorio.com/Mod_details_API#Category
type Category struct {
	Value       string
	Name        string
	Description string
}

var categories = map[string]Category{
	"":              {"", "No category", "Unassigned category"},
	"no-category":   {"", "No category", "Unassigned category"},
	"content":       {"content", "Content", "Mods introducing new content into the game"},
	"overhaul":      {"overhaul", "Overhaul", "Large total conversion mods"},
	"tweaks":        {"tweaks", "Tweaks", "Small changes concerning balance, gameplay, or graphics"},
	"utilities":     {"utilities", "Utilities", "Providing the player with new tools or adjusting the game interface"},
	"scenarios":     {"scenarios", "Scenarios", "Scenarios, maps, and puzzles"},
	"mod-packs":     {"mod-packs", "Mod packs", "Collections of mods with tweaks to make them work together"},
	"localizations": {"localizations", "Localizations", "Translations for other mods"},
	"internal":      {"internal", "Internal", "Lua libraries for use by other mods"},
}

// CategoryFor returns the display Category for a raw API category value.
// Categories change rarely; an unrecognized value means this catalog is
// out of date and needs a code change, not a value to paper over, so this
// errors rather than degrading to a raw-string display (matching Ruby's
// Category.for, which raises KeyError for the same case).
func CategoryFor(value string) (Category, error) {
	if c, ok := categories[value]; ok {
		return c, nil
	}
	return Category{}, fmt.Errorf("%w: unknown category %q", ErrInvalidResponse, value)
}
