package dependency

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func errorTypes(result *ValidationResult) []ErrorType {
	types := make([]ErrorType, len(result.Errors))
	for i, e := range result.Errors {
		types[i] = e.Type
	}
	return types
}

func warningTypes(result *ValidationResult) []WarningType {
	types := make([]WarningType, len(result.Warnings))
	for i, w := range result.Warnings {
		types[i] = w.Type
	}
	return types
}

func TestValidatorValid(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app", "lib")
	requireEdge(t, g, "app", "lib", TypeRequired)

	list := mod.NewMODList()
	require.NoError(t, list.Add(testMOD("app"), mod.MODState{Enabled: true}))
	require.NoError(t, list.Add(testMOD("lib"), mod.MODState{Enabled: true}))

	result := (&Validator{Graph: g, MODList: list}).Validate()
	assert.True(t, result.Valid())
	assert.Empty(t, result.Warnings)
}

func TestValidatorMissingDependency(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app")
	requireEdge(t, g, "app", "ghost", TypeRequired)

	result := (&Validator{Graph: g, MODList: mod.NewMODList()}).Validate()
	assert.Contains(t, errorTypes(result), ErrorMissingDependency)
}

func TestValidatorDisabledDependency(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app")
	require.NoError(t, g.AddNode(Node{MOD: testMOD("lib"), Version: mod.MODVersion{Major: 1}, Enabled: false, Installed: true}))
	requireEdge(t, g, "app", "lib", TypeRequired)

	result := (&Validator{Graph: g, MODList: mod.NewMODList()}).Validate()
	assert.Contains(t, errorTypes(result), ErrorDisabledDependency)
}

func TestValidatorRecommendedDependencyDisabled(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app")
	require.NoError(t, g.AddNode(Node{MOD: testMOD("lib"), Version: mod.MODVersion{Major: 1}, Enabled: false, Installed: true}))
	requireEdge(t, g, "app", "lib", TypeRecommended)

	result := (&Validator{Graph: g, MODList: mod.NewMODList()}).Validate()
	assert.True(t, result.Valid()) // a disabled recommended dependency is a warning, not an error
	assert.Contains(t, warningTypes(result), WarningRecommendedDependencyDisabled)
}

func TestValidatorRecommendedDependencyNotInstalled(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app")
	requireEdge(t, g, "app", "ghost", TypeRecommended)

	result := (&Validator{Graph: g, MODList: mod.NewMODList()}).Validate()
	assert.True(t, result.Valid())
	assert.NotContains(t, warningTypes(result), WarningRecommendedDependencyDisabled)
}

func TestValidatorVersionMismatchWithSuggestion(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app", "lib") // lib is at version 1
	require.NoError(t, g.AddEdge(Edge{
		From: testMOD("app"), To: testMOD("lib"), Type: TypeRequired,
		Requirement: &VersionRequirement{Operator: OpGreaterEqual, Version: mod.MODVersion{Major: 2}},
	}))

	installed := []mod.InstalledMOD{installedMOD("lib", "2.0.0")}
	result := (&Validator{Graph: g, MODList: mod.NewMODList(), InstalledMODs: installed}).Validate()

	assert.Contains(t, errorTypes(result), ErrorVersionMismatch)
	require.Len(t, result.Suggestions, 1)
	assert.Equal(t, testMOD("lib"), result.Suggestions[0].MOD)
	assert.Equal(t, mod.MODVersion{Major: 2}, result.Suggestions[0].Version)
}

func TestValidatorConflict(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app", "rival")
	requireEdge(t, g, "app", "rival", TypeIncompatible)

	result := (&Validator{Graph: g, MODList: mod.NewMODList()}).Validate()
	assert.Contains(t, errorTypes(result), ErrorConflict)
}

func TestValidatorCircularDependency(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "a", "b")
	requireEdge(t, g, "a", "b", TypeRequired)
	requireEdge(t, g, "b", "a", TypeRequired)

	result := (&Validator{Graph: g, MODList: mod.NewMODList()}).Validate()
	assert.Contains(t, errorTypes(result), ErrorCircularDependency)
}

func TestValidatorMODListWarnings(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "installed-only")

	list := mod.NewMODList()
	require.NoError(t, list.Add(testMOD("listed-only"), mod.MODState{Enabled: true}))

	result := (&Validator{Graph: g, MODList: list}).Validate()
	assert.True(t, result.Valid())
	require.Len(t, result.Warnings, 2)
	assert.Equal(t, WarningMODInListNotInstalled, result.Warnings[0].Type)
	assert.Equal(t, testMOD("listed-only"), result.Warnings[0].MOD)
	assert.Equal(t, WarningMODInstalledNotInList, result.Warnings[1].Type)
	assert.Equal(t, testMOD("installed-only"), result.Warnings[1].MOD)
}
