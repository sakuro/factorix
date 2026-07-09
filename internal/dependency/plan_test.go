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

func TestAddUninstalledMOD(t *testing.T) {
	g := NewGraph()
	require.NoError(t, g.AddUninstalledMOD(testMOD("new-mod"), mod.MODVersion{Major: 2}, []string{"base", "lib >= 1.0", "? optional-lib"}))

	node, ok := g.Node(testMOD("new-mod"))
	require.True(t, ok)
	assert.Equal(t, OpInstall, node.Operation)
	assert.False(t, node.Installed)
	assert.False(t, node.Enabled)

	edges := g.EdgesFrom(testMOD("new-mod"))
	require.Len(t, edges, 2) // base edge skipped
	assert.Equal(t, testMOD("lib"), edges[0].To)
	assert.Equal(t, TypeRequired, edges[0].Type)
	assert.Equal(t, testMOD("optional-lib"), edges[1].To)
	assert.Equal(t, TypeOptional, edges[1].Type)
}

func TestAddUninstalledMODExistingDisabled(t *testing.T) {
	g := NewGraph()
	disabledNode(t, g, "present-mod")

	require.NoError(t, g.AddUninstalledMOD(testMOD("present-mod"), mod.MODVersion{Major: 9}, []string{"lib"}))

	node, ok := g.Node(testMOD("present-mod"))
	require.True(t, ok)
	assert.Equal(t, OpEnable, node.Operation)
	// The existing node is untouched otherwise: no new edges, version kept.
	assert.Equal(t, mod.MODVersion{Major: 1}, node.Version)
	assert.Empty(t, g.EdgesFrom(testMOD("present-mod")))
}

func TestAddUninstalledMODExistingEnabled(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "enabled-mod")

	require.NoError(t, g.AddUninstalledMOD(testMOD("enabled-mod"), mod.MODVersion{Major: 9}, nil))

	node, ok := g.Node(testMOD("enabled-mod"))
	require.True(t, ok)
	assert.Equal(t, OpNone, node.Operation)
}

func TestAddUninstalledMODInvalidDependency(t *testing.T) {
	g := NewGraph()
	err := g.AddUninstalledMOD(testMOD("broken"), mod.MODVersion{Major: 1}, []string{">= 1.0"})
	var parseErr *ParseError
	require.ErrorAs(t, err, &parseErr)
}

func TestMarkDisabledDependenciesForEnable(t *testing.T) {
	g := NewGraph()
	// new-mod (install) -> lib (installed, disabled) -> sublib (installed, disabled)
	require.NoError(t, g.AddUninstalledMOD(testMOD("new-mod"), mod.MODVersion{Major: 1}, []string{"lib"}))
	disabledNode(t, g, "lib")
	disabledNode(t, g, "sublib")
	requireEdge(t, g, "lib", "sublib", TypeRequired)
	// An optional dependency stays untouched.
	disabledNode(t, g, "optional-lib")
	requireEdge(t, g, "new-mod", "optional-lib", TypeOptional)

	MarkDisabledDependenciesForEnable(g)

	lib, _ := g.Node(testMOD("lib"))
	assert.Equal(t, OpEnable, lib.Operation)
	sublib, _ := g.Node(testMOD("sublib"))
	assert.Equal(t, OpEnable, sublib.Operation)
	optional, _ := g.Node(testMOD("optional-lib"))
	assert.Equal(t, OpNone, optional.Operation)
}

func TestValidateInstallGraphCycle(t *testing.T) {
	g := NewGraph()
	require.NoError(t, g.AddUninstalledMOD(testMOD("a"), mod.MODVersion{Major: 1}, []string{"b"}))
	require.NoError(t, g.AddUninstalledMOD(testMOD("b"), mod.MODVersion{Major: 1}, []string{"a"}))

	err := ValidateInstallGraph(g)
	require.ErrorIs(t, err, ErrCircularDependency)
}

func TestValidateInstallGraphConflict(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "rival") // enabled
	require.NoError(t, g.AddUninstalledMOD(testMOD("new-mod"), mod.MODVersion{Major: 1}, []string{"! rival"}))

	err := ValidateInstallGraph(g)
	require.ErrorIs(t, err, ErrMODConflict)
	assert.Contains(t, err.Error(), "conflicts with enabled MOD rival")
}

func TestValidateInstallGraphOK(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "lib")
	require.NoError(t, g.AddUninstalledMOD(testMOD("new-mod"), mod.MODVersion{Major: 1}, []string{"lib"}))

	require.NoError(t, ValidateInstallGraph(g))
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
