// Package resolver selects MOD Portal releases and (in later stages)
// resolves MOD dependencies against the Portal. It is the single place
// where "latest" is defined for every command.
package resolver

import (
	"slices"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

// SelectLatest returns the MOD's latest release: the Portal's
// latest_release field when present, otherwise the highest version among
// Releases. The full endpoint is known to always omit latest_release, so
// the fallback is the common path (#180). Returns nil when the MOD has no
// releases.
func SelectLatest(info *api.MODInfo) *api.Release {
	if info.LatestRelease != nil {
		return info.LatestRelease
	}
	return highestVersion(info.Releases)
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

// SelectCompatible returns the latest release satisfying the requirement:
// with a nil requirement it is SelectLatest; otherwise latest_release when
// that satisfies the requirement, else the highest satisfying version.
// Returns nil when no release satisfies.
func SelectCompatible(info *api.MODInfo, requirement *dependency.VersionRequirement) *api.Release {
	if requirement == nil {
		return SelectLatest(info)
	}
	if info.LatestRelease != nil && requirement.SatisfiedBy(info.LatestRelease.Version) {
		return info.LatestRelease
	}
	var compatible []api.Release
	for _, r := range info.Releases {
		if requirement.SatisfiedBy(r.Version) {
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
