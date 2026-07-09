package dependency

import (
	"fmt"

	"github.com/sakuro/factorix/internal/mod"
)

// Operation is a planned action on a graph node.
type Operation uint8

const (
	OpNone Operation = iota
	OpInstall
	OpEnable
	OpDisable
	OpUninstall
)

func (o Operation) String() string {
	switch o {
	case OpNone:
		return "none"
	case OpInstall:
		return "install"
	case OpEnable:
		return "enable"
	case OpDisable:
		return "disable"
	case OpUninstall:
		return "uninstall"
	default:
		return fmt.Sprintf("Operation(%d)", uint8(o))
	}
}

// Node is a MOD in the dependency graph with its state.
type Node struct {
	MOD       mod.MOD
	Version   mod.MODVersion
	Enabled   bool
	Installed bool
	Operation Operation
}

// Edge is a dependency relation from one MOD to another.
type Edge struct {
	From        mod.MOD
	To          mod.MOD
	Type        Type
	Requirement *VersionRequirement
}

// SatisfiedBy reports whether the given version satisfies the edge's
// version requirement; edges without a requirement are always satisfied.
func (e Edge) SatisfiedBy(v mod.MODVersion) bool {
	if e.Requirement == nil {
		return true
	}
	return e.Requirement.SatisfiedBy(v)
}

// Graph is a directed graph of MOD dependencies. Nodes keep their insertion
// order so sorting and cycle reporting are deterministic.
type Graph struct {
	order []mod.MOD
	nodes map[mod.MOD]Node
	edges map[mod.MOD][]Edge
}

// NewGraph returns an empty graph.
func NewGraph() *Graph {
	return &Graph{nodes: map[mod.MOD]Node{}, edges: map[mod.MOD][]Edge{}}
}

// AddNode adds a node; adding a MOD twice is an error.
func (g *Graph) AddNode(n Node) error {
	if _, ok := g.nodes[n.MOD]; ok {
		return fmt.Errorf("%w: %s", ErrNodeExists, n.MOD)
	}
	g.order = append(g.order, n.MOD)
	g.nodes[n.MOD] = n
	return nil
}

// SetNodeOperation sets the planned operation of an existing node; missing
// nodes are ignored.
func (g *Graph) SetNodeOperation(m mod.MOD, op Operation) {
	node, ok := g.nodes[m]
	if !ok {
		return
	}
	node.Operation = op
	g.nodes[m] = node
}

// AddUninstalledMOD extends the graph with a MOD fetched from the Portal
// (used by mod install to plan alongside the installed MODs). If the MOD is
// already in the graph, an installed-but-disabled node is marked for
// enabling and nothing else changes. Otherwise a node with operation
// install is added, with edges parsed from the release's dependency
// strings (edges to the always-available base MOD carry no information and
// are skipped, as in the builder).
func (g *Graph) AddUninstalledMOD(m mod.MOD, version mod.MODVersion, dependencyStrings []string) error {
	if existing, ok := g.nodes[m]; ok {
		if existing.Installed && !existing.Enabled {
			g.SetNodeOperation(m, OpEnable)
		}
		return nil
	}

	if err := g.AddNode(Node{MOD: m, Version: version, Operation: OpInstall}); err != nil {
		return err
	}
	for _, depString := range dependencyStrings {
		entry, err := Parse(depString)
		if err != nil {
			return err
		}
		if entry.MOD.IsBase() {
			continue
		}
		if err := g.AddEdge(Edge{From: m, To: entry.MOD, Type: entry.Type, Requirement: entry.Requirement}); err != nil {
			return err
		}
	}
	return nil
}

// AddEdge adds an edge; the origin node must exist.
func (g *Graph) AddEdge(e Edge) error {
	if _, ok := g.nodes[e.From]; !ok {
		return fmt.Errorf("%w: %s", ErrNodeMissing, e.From)
	}
	g.edges[e.From] = append(g.edges[e.From], e)
	return nil
}

// Node returns the node for the MOD; ok is false when absent.
func (g *Graph) Node(m mod.MOD) (Node, bool) {
	n, ok := g.nodes[m]
	return n, ok
}

// Contains reports whether the graph has a node for the MOD.
func (g *Graph) Contains(m mod.MOD) bool {
	_, ok := g.nodes[m]
	return ok
}

// Len returns the number of nodes.
func (g *Graph) Len() int {
	return len(g.order)
}

// Nodes returns all nodes in insertion order.
func (g *Graph) Nodes() []Node {
	nodes := make([]Node, 0, len(g.order))
	for _, m := range g.order {
		nodes = append(nodes, g.nodes[m])
	}
	return nodes
}

// EdgesFrom returns the edges originating from the MOD.
func (g *Graph) EdgesFrom(m mod.MOD) []Edge {
	return g.edges[m]
}

// EdgesTo returns the edges pointing at the MOD.
func (g *Graph) EdgesTo(m mod.MOD) []Edge {
	var result []Edge
	for _, from := range g.order {
		for _, e := range g.edges[from] {
			if e.To == m {
				result = append(result, e)
			}
		}
	}
	return result
}

// FindEnabledDependents returns the enabled MODs that have a required
// dependency on the given MOD.
func (g *Graph) FindEnabledDependents(m mod.MOD) []mod.MOD {
	var dependents []mod.MOD
	for _, from := range g.order {
		node := g.nodes[from]
		if !node.Enabled {
			continue
		}
		for _, e := range g.edges[from] {
			if e.Type == TypeRequired && e.To == m {
				dependents = append(dependents, from)
				break
			}
		}
	}
	return dependents
}

// requiredDeps returns the MODs the given MOD requires, restricted to MODs
// present in the graph. Only required edges participate in ordering and
// cycle detection: optional cycles are allowed in Factorio.
func (g *Graph) requiredDeps(m mod.MOD) []mod.MOD {
	var deps []mod.MOD
	for _, e := range g.edges[m] {
		if e.Type != TypeRequired {
			continue
		}
		if _, ok := g.nodes[e.To]; ok {
			deps = append(deps, e.To)
		}
	}
	return deps
}

// TopologicalSort returns the MODs with every dependency ordered before its
// dependents (Kahn's algorithm). It fails with ErrCircularDependency when
// the graph has a required-dependency cycle.
func (g *Graph) TopologicalSort() ([]mod.MOD, error) {
	// pending counts each node's unemitted required dependencies;
	// dependents is the reverse adjacency used to decrement them.
	pending := make(map[mod.MOD]int, len(g.order))
	dependents := make(map[mod.MOD][]mod.MOD, len(g.order))
	for _, m := range g.order {
		deps := g.requiredDeps(m)
		pending[m] = len(deps)
		for _, dep := range deps {
			dependents[dep] = append(dependents[dep], m)
		}
	}

	var queue []mod.MOD
	for _, m := range g.order {
		if pending[m] == 0 {
			queue = append(queue, m)
		}
	}

	sorted := make([]mod.MOD, 0, len(g.order))
	for len(queue) > 0 {
		m := queue[0]
		queue = queue[1:]
		sorted = append(sorted, m)
		for _, dependent := range dependents[m] {
			pending[dependent]--
			if pending[dependent] == 0 {
				queue = append(queue, dependent)
			}
		}
	}

	if len(sorted) < len(g.order) {
		return nil, ErrCircularDependency
	}
	return sorted, nil
}

// IsCyclic reports whether the graph has a required-dependency cycle.
func (g *Graph) IsCyclic() bool {
	_, err := g.TopologicalSort()
	return err != nil
}

// StronglyConnectedComponents returns the strongly connected components of
// the required-dependency graph (Tarjan's algorithm). Cycles are the
// components with more than one member.
func (g *Graph) StronglyConnectedComponents() [][]mod.MOD {
	index := 0
	indices := map[mod.MOD]int{}
	lowlinks := map[mod.MOD]int{}
	onStack := map[mod.MOD]bool{}
	var stack []mod.MOD
	var components [][]mod.MOD

	var strongConnect func(m mod.MOD)
	strongConnect = func(m mod.MOD) {
		indices[m] = index
		lowlinks[m] = index
		index++
		stack = append(stack, m)
		onStack[m] = true

		for _, dep := range g.requiredDeps(m) {
			if _, visited := indices[dep]; !visited {
				strongConnect(dep)
				lowlinks[m] = min(lowlinks[m], lowlinks[dep])
			} else if onStack[dep] {
				lowlinks[m] = min(lowlinks[m], indices[dep])
			}
		}

		if lowlinks[m] == indices[m] {
			var component []mod.MOD
			for {
				top := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				onStack[top] = false
				component = append(component, top)
				if top == m {
					break
				}
			}
			components = append(components, component)
		}
	}

	for _, m := range g.order {
		if _, visited := indices[m]; !visited {
			strongConnect(m)
		}
	}
	return components
}
