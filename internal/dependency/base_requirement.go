package dependency

import "github.com/sakuro/factorix/internal/mod"

// EffectiveBaseRequirement returns the version requirement a release places
// on the base MOD (i.e. the installed Factorio game version): the explicit
// required "base" entry in dependencyStrings when present — even without a
// version, in which case nil means "any version" and factorioVersion is
// ignored — otherwise a synthesized ">= factorioVersion". A non-required
// "base" entry (optional "?", hidden-optional "(?)", incompatible "!",
// load-neutral "~", or recommended "+") does not count as an explicit
// requirement and falls through to the factorio_version fallback as if no
// "base" entry were present. Returns nil when neither source yields a
// requirement. Malformed entries are skipped rather than treated as errors,
// matching Parse's own leniency toward the Portal's occasionally odd data.
func EffectiveBaseRequirement(dependencyStrings []string, factorioVersion string) *VersionRequirement {
	for _, depString := range dependencyStrings {
		entry, err := Parse(depString)
		if err != nil || !entry.MOD.IsBase() || entry.Type != TypeRequired {
			continue
		}
		return entry.Requirement
	}

	if factorioVersion == "" {
		return nil
	}
	version, err := mod.ParseMODVersion(factorioVersion)
	if err != nil {
		return nil
	}
	return &VersionRequirement{Operator: OpGreaterEqual, Version: version}
}
