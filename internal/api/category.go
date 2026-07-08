package api

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
// An unrecognized value (the Portal may add categories after this catalog
// was last updated) falls back to a Category using the raw value as its
// name, rather than failing outright the way Ruby's Category.for does.
func CategoryFor(value string) Category {
	if c, ok := categories[value]; ok {
		return c
	}
	return Category{Value: value, Name: value}
}
