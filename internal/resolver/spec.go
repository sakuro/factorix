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
func (s Spec) Select(info *api.MODInfo) *api.Release {
	if s.Latest {
		return SelectLatest(info)
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
