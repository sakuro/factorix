package dependency

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func testMOD(name string) mod.MOD {
	return mod.MOD{Name: name}
}

func addNodes(t *testing.T, g *Graph, names ...string) {
	t.Helper()
	for _, name := range names {
		require.NoError(t, g.AddNode(Node{MOD: testMOD(name), Version: mod.MODVersion{Major: 1}, Enabled: true, Installed: true}))
	}
}

func requireEdge(t *testing.T, g *Graph, from, to string, typ Type) {
	t.Helper()
	require.NoError(t, g.AddEdge(Edge{From: testMOD(from), To: testMOD(to), Type: typ}))
}

func TestGraphAddNode(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "a")
	assert.True(t, g.Contains(testMOD("a")))
	assert.Equal(t, 1, g.Len())

	err := g.AddNode(Node{MOD: testMOD("a")})
	require.ErrorIs(t, err, ErrNodeExists)
}

func TestGraphAddEdgeMissingNode(t *testing.T) {
	g := NewGraph()
	err := g.AddEdge(Edge{From: testMOD("ghost"), To: testMOD("a")})
	require.ErrorIs(t, err, ErrNodeMissing)
}

func TestGraphSetNodeOperation(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "a")
	g.SetNodeOperation(testMOD("a"), OpEnable)
	node, ok := g.Node(testMOD("a"))
	require.True(t, ok)
	assert.Equal(t, OpEnable, node.Operation)

	g.SetNodeOperation(testMOD("missing"), OpEnable) // no-op
}

func TestGraphTopologicalSort(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "app", "lib", "core")
	requireEdge(t, g, "app", "lib", TypeRequired)
	requireEdge(t, g, "lib", "core", TypeRequired)

	sorted, err := g.TopologicalSort()
	require.NoError(t, err)
	assert.Equal(t, []mod.MOD{testMOD("core"), testMOD("lib"), testMOD("app")}, sorted)
}

func TestGraphTopologicalSortIgnoresNonRequiredEdges(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "a", "b")
	// An optional cycle is allowed in Factorio and must not fail the sort.
	requireEdge(t, g, "a", "b", TypeOptional)
	requireEdge(t, g, "b", "a", TypeOptional)

	_, err := g.TopologicalSort()
	require.NoError(t, err)
	assert.False(t, g.IsCyclic())
}

func TestGraphCycle(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "a", "b", "c")
	requireEdge(t, g, "a", "b", TypeRequired)
	requireEdge(t, g, "b", "a", TypeRequired)

	_, err := g.TopologicalSort()
	require.ErrorIs(t, err, ErrCircularDependency)
	assert.True(t, g.IsCyclic())

	var cycles [][]mod.MOD
	for _, component := range g.StronglyConnectedComponents() {
		if len(component) > 1 {
			cycles = append(cycles, component)
		}
	}
	require.Len(t, cycles, 1)
	assert.ElementsMatch(t, []mod.MOD{testMOD("a"), testMOD("b")}, cycles[0])
}

func TestGraphEdgesToAndDependents(t *testing.T) {
	g := NewGraph()
	addNodes(t, g, "a", "b", "c")
	require.NoError(t, g.AddNode(Node{MOD: testMOD("d"), Version: mod.MODVersion{Major: 1}, Enabled: false, Installed: true}))
	requireEdge(t, g, "a", "c", TypeRequired)
	requireEdge(t, g, "b", "c", TypeOptional)
	requireEdge(t, g, "d", "c", TypeRequired)

	assert.Len(t, g.EdgesTo(testMOD("c")), 3)

	// Only enabled MODs with a *required* edge count as dependents.
	assert.Equal(t, []mod.MOD{testMOD("a")}, g.FindEnabledDependents(testMOD("c")))
}
