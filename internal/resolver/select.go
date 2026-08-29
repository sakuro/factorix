// Package resolver selects MOD Portal releases and resolves MOD
// dependencies against the Portal. It is the single place where "latest"
// is defined for every command.
package resolver

import (
	"slices"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

// SelectLatest returns the MOD's latest release compatible with
// installedBase (nil skips the compatibility check): the Portal's
// latest_release field when present and compatible, otherwise the highest
// compatible version among Releases. The full endpoint is known to always
// omit latest_release, so the fallback is the common path (#180). Returns
// nil when the MOD has no compatible release.
func SelectLatest(info *api.MODInfo, installedBase *mod.MODVersion) *api.Release {
	if info.LatestRelease != nil && gameCompatible(*info.LatestRelease, installedBase) {
		return info.LatestRelease
	}
	return highestCompatibleVersion(info.Releases, installedBase)
}

// SelectExact returns the release with exactly the given version, or nil.
func SelectExact(info *api.MODInfo, version mod.MODVersion) *api.Release {
	for i := range info.Releases {
		if info.Releases[i].Version == version {
			return &info.Releases[i]
		}
	}
	return nil
}

// SelectCompatible returns the latest release satisfying every given
// requirement (nil requirements are ignored) and compatible with
// installedBase (nil skips the compatibility check): with no effective
// requirement it is SelectLatest; otherwise latest_release when that
// satisfies all requirements and is compatible, else the highest
// satisfying, compatible version. Returns nil when no release satisfies.
func SelectCompatible(info *api.MODInfo, installedBase *mod.MODVersion, requirements ...*dependency.VersionRequirement) *api.Release {
	var active []*dependency.VersionRequirement
	for _, r := range requirements {
		if r != nil {
			active = append(active, r)
		}
	}
	if len(active) == 0 {
		return SelectLatest(info, installedBase)
	}
	satisfiesAll := func(v mod.MODVersion) bool {
		for _, r := range active {
			if !r.SatisfiedBy(v) {
				return false
			}
		}
		return true
	}
	if info.LatestRelease != nil && satisfiesAll(info.LatestRelease.Version) && gameCompatible(*info.LatestRelease, installedBase) {
		return info.LatestRelease
	}
	var compatible []api.Release
	for _, r := range info.Releases {
		if satisfiesAll(r.Version) && gameCompatible(r, installedBase) {
			compatible = append(compatible, r)
		}
	}
	return highestVersion(compatible)
}

// gameCompatible reports whether release is compatible with installedBase:
// true when installedBase is nil (compatibility unknown - do not filter),
// or the release declares no base requirement (neither an explicit "base"
// dependency entry nor factorio_version), or installedBase satisfies the
// requirement.
func gameCompatible(release api.Release, installedBase *mod.MODVersion) bool {
	if installedBase == nil {
		return true
	}
	requirement := dependency.EffectiveBaseRequirement(release.InfoJSON.Dependencies, release.InfoJSON.FactorioVersion)
	if requirement == nil {
		return true
	}
	return requirement.SatisfiedBy(*installedBase)
}

func highestCompatibleVersion(releases []api.Release, installedBase *mod.MODVersion) *api.Release {
	var compatible []api.Release
	for _, r := range releases {
		if gameCompatible(r, installedBase) {
			compatible = append(compatible, r)
		}
	}
	return highestVersion(compatible)
}

func highestVersion(releases []api.Release) *api.Release {
	if len(releases) == 0 {
		return nil
	}
	highest := slices.MaxFunc(releases, func(a, b api.Release) int {
		return a.Version.Compare(b.Version)
	})
	return &highest
}
