package dependency

import (
	"github.com/sakuro/factorix/internal/mod"
)

// BuildGraph constructs the dependency graph of the installed MODs:
// one node per MOD (enabled state from mod-list.json) and one edge per
// dependency declared in the active version's info.json.
func BuildGraph(installedMODs []mod.InstalledMOD, modList *mod.MODList) (*Graph, error) {
	graph := NewGraph()

	var uniqueMODs []mod.MOD
	seen := map[mod.MOD]bool{}
	for _, im := range installedMODs {
		if !seen[im.MOD] {
			seen[im.MOD] = true
			uniqueMODs = append(uniqueMODs, im.MOD)
		}
	}

	activeVersions := make(map[mod.MOD]mod.MODVersion, len(uniqueMODs))
	for _, m := range uniqueMODs {
		version := selectVersion(m, installedMODs, modList)
		activeVersions[m] = version
		if err := graph.AddNode(Node{
			MOD:       m,
			Version:   version,
			Enabled:   modEnabled(m, modList),
			Installed: true,
		}); err != nil {
			return nil, err
		}
	}

	// Only the active version of each MOD contributes edges.
	for _, im := range installedMODs {
		if activeVersions[im.MOD] != im.Version {
			continue
		}
		for _, depString := range im.Info.Dependencies {
			entry, err := Parse(depString)
			if err != nil {
				return nil, err
			}
			// The base MOD is always available and cannot be disabled, so
			// edges to it carry no information. Expansion MODs can be
			// disabled and must be validated like any other dependency.
			if entry.MOD.IsBase() {
				continue
			}
			if err := graph.AddEdge(Edge{
				From:        im.MOD,
				To:          entry.MOD,
				Type:        entry.Type,
				Requirement: entry.Requirement,
			}); err != nil {
				return nil, err
			}
		}
	}

	return graph, nil
}

// selectVersion picks the version the game would load: the version pinned in
// mod-list.json when that exact version is installed, otherwise the newest
// installed version.
func selectVersion(m mod.MOD, installedMODs []mod.InstalledMOD, modList *mod.MODList) mod.MODVersion {
	if modList.Contains(m) {
		if pinned, err := modList.Version(m); err == nil && pinned != nil {
			for _, im := range installedMODs {
				if im.MOD == m && im.Version == *pinned {
					return *pinned
				}
			}
		}
	}

	var newest mod.MODVersion
	for _, im := range installedMODs {
		if im.MOD == m && newest.Less(im.Version) {
			newest = im.Version
		}
	}
	return newest
}

func modEnabled(m mod.MOD, modList *mod.MODList) bool {
	enabled, err := modList.Enabled(m)
	return err == nil && enabled
}
