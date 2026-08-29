package resolver

import (
	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/mod"
)

// Spec is a parsed MOD specification: a name plus either "latest" or an
// exact version.
type Spec struct {
	MOD     mod.MOD
	Latest  bool
	Version mod.MODVersion // meaningless when Latest
}

// Select returns the release the spec designates, or nil when absent.
// installedBase (nil skips the check) filters out game-incompatible
// releases when Latest is set; an exact version request is never filtered
// — the user asked for that version specifically.
func (s Spec) Select(info *api.MODInfo, installedBase *mod.MODVersion) *api.Release {
	if s.Latest {
		return SelectLatest(info, installedBase)
	}
	return SelectExact(info, s.Version)
}

// VersionLabel renders the requested version for error messages.
func (s Spec) VersionLabel() string {
	if s.Latest {
		return "latest"
	}
	return s.Version.String()
}
