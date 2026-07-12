package cli

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMODCheckAllSatisfied(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"lib"})
	s.writeInstalledMOD(t, "lib", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: true},
		modListEntry{name: "lib", enabled: true},
	)

	out, err := runCLI(t, "mod", "check")
	require.NoError(t, err)
	assert.Contains(t, out, "All enabled MOD(s) have their required dependencies satisfied")
	assert.NotContains(t, out, "Warnings:")
}

func TestMODCheckWarnsAboutDisabledRecommendedDependency(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"+ lib"})
	s.writeInstalledMOD(t, "lib", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: true},
		modListEntry{name: "lib", enabled: false},
	)

	out, err := runCLI(t, "mod", "check")
	require.NoError(t, err)
	assert.Contains(t, out, "Warnings:")
	assert.Contains(t, out, "recommends 'lib' which is not enabled")
}

func TestMODCheckIgnoresRecommendedWarningWithFlag(t *testing.T) {
	s := baseSandbox(t)
	s.writeInstalledMOD(t, "app", "1.0.0", []string{"+ lib"})
	s.writeInstalledMOD(t, "lib", "1.0.0", nil)
	s.writeMODList(t,
		modListEntry{name: "base", enabled: true},
		modListEntry{name: "app", enabled: true},
		modListEntry{name: "lib", enabled: false},
	)

	out, err := runCLI(t, "mod", "check", "--ignore-recommended")
	require.NoError(t, err)
	assert.NotContains(t, out, "Warnings:")
	assert.NotContains(t, out, "recommends 'lib' which is not enabled")
}
