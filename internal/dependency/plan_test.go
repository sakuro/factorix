package dependency

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func disabledNode(t *testing.T, g *Graph, name string) {
	t.Helper()
	require.NoError(t, g.AddNode(Node{MOD: testMOD(name), Version: mod.MODVersion{Major: 1}, Enabled: false, Installed: true}))
}

func TestPlanEnablePullsInRequiredDeps(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "app")
	disabledNode(t, g, "lib")
	requireEdge(t, g, "app", "lib", TypeRequired)
	requireEdge(t, g, "app", "base", TypeRequired) // base is skipped

	planned, err := PlanEnable(g, []mod.MOD{testMOD("app")})
	require.NoError(t, err)
	assert.Equal(t, []mod.MOD{testMOD("app"), testMOD("lib")}, planned)
}

func TestPlanEnableSkipsAlreadyEnabled(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "app")
	addNodes(t, g, "lib") // enabled
	requireEdge(t, g, "app", "lib", TypeRequired)

	planned, err := PlanEnable(g, []mod.MOD{testMOD("app")})
	require.NoError(t, err)
	assert.Equal(t, []mod.MOD{testMOD("app")}, planned)
}

func TestPlanEnableMissingDependency(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "app")
	requireEdge(t, g, "app", "ghost", TypeRequired)

	_, err := PlanEnable(g, []mod.MOD{testMOD("app")})
	require.ErrorIs(t, err, ErrDependencyMissing)
}

func TestPlanEnableVersionMismatch(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "app")
	disabledNode(t, g, "lib") // version 1
	require.NoError(t, g.AddEdge(Edge{
		From: testMOD("app"), To: testMOD("lib"), Type: TypeRequired,
		Requirement: &VersionRequirement{Operator: OpGreaterEqual, Version: mod.MODVersion{Major: 2}},
	}))

	_, err := PlanEnable(g, []mod.MOD{testMOD("app")})
	require.ErrorIs(t, err, ErrDependencyVersion)
}

func TestValidateNoConflictsWithEnabled(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "app")
	addNodes(t, g, "rival") // enabled
	requireEdge(t, g, "app", "rival", TypeIncompatible)

	err := ValidateNoConflicts(g, []mod.MOD{testMOD("app")})
	require.ErrorIs(t, err, ErrMODConflict)
}

func TestValidateNoConflictsWithinPlan(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "a")
	disabledNode(t, g, "b")
	requireEdge(t, g, "a", "b", TypeIncompatible)

	err := ValidateNoConflicts(g, []mod.MOD{testMOD("a"), testMOD("b")})
	require.ErrorIs(t, err, ErrMODConflict)
}

func TestValidateNoConflictsIncomingEdge(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "app")
	addNodes(t, g, "rival") // enabled
	requireEdge(t, g, "rival", "app", TypeIncompatible)

	err := ValidateNoConflicts(g, []mod.MOD{testMOD("app")})
	require.ErrorIs(t, err, ErrMODConflict)
}

func TestValidateNoConflictsPasses(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "app")

	err := ValidateNoConflicts(g, []mod.MOD{testMOD("app")})
	require.NoError(t, err)
}

func TestPlanDisableAll(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "base", "app") // both enabled
	require.NoError(t, g.AddNode(Node{MOD: testMOD("off"), Version: mod.MODVersion{Major: 1}, Enabled: false, Installed: true}))

	planned := PlanDisableAll(g)
	assert.ElementsMatch(t, []mod.MOD{testMOD("app")}, planned)
}

func TestPlanDisablePullsInDependents(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app", "lib")
	requireEdge(t, g, "app", "lib", TypeRequired)

	planned := PlanDisable(g, []mod.MOD{testMOD("lib")})
	assert.Equal(t, []mod.MOD{testMOD("lib"), testMOD("app")}, planned)
}

func TestPlanDisableSkipsNotInstalledOrAlreadyDisabled(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app")

	planned := PlanDisable(g, []mod.MOD{testMOD("ghost"), testMOD("app")})
	assert.Equal(t, []mod.MOD{testMOD("app")}, planned)

	disabledNode(t, g, "off")
	planned = PlanDisable(g, []mod.MOD{testMOD("off")})
	assert.Empty(t, planned)
}
