package dependency

import (
	"errors"
	"fmt"

	"github.com/sakuro/factorix/internal/mod"
)

var (
	ErrDependencyMissing = errors.New("dependency missing")
	ErrDependencyVersion = errors.New("dependency version requirement not satisfied")
	ErrMODConflict       = errors.New("MOD conflict")
)

// PlanEnable computes the MODs to enable when enabling targets, pulling in
// required dependencies (BFS discovery order). When includeRecommended is
// true, recommended dependencies are pulled in the same way when already
// installed with a satisfied version; unlike required dependencies, a
// missing or version-mismatched recommended dependency is silently skipped
// rather than rejected, since it's off by default only by the user's own
// choice not to install it (fetching it from the Portal is out of scope
// here, see #91). When includeRecommended is false, recommended edges are
// ignored entirely (the --ignore-recommended opt-out). The base MOD is
// always available and is never pulled in as a dependency. Targets already
// installed are assumed to exist in the graph; the caller validates that
// before calling PlanEnable.
func PlanEnable(g *Graph, targets []mod.MOD, includeRecommended bool) ([]mod.MOD, error) {
	planned := map[mod.MOD]bool{}
	var order []mod.MOD
	queue := append([]mod.MOD(nil), targets...)

	for len(queue) > 0 {
		m := queue[0]
		queue = queue[1:]

		node, ok := g.Node(m)
		if !ok || node.Enabled || planned[m] {
			continue
		}
		planned[m] = true
		order = append(order, m)

		for _, edge := range g.EdgesFrom(m) {
			if edge.To.IsBase() {
				continue
			}
			if edge.Type == TypeRecommended && !includeRecommended {
				continue
			}
			switch edge.Type {
			case TypeRequired:
				depNode, ok := g.Node(edge.To)
				if !ok {
					return nil, fmt.Errorf("%w: MOD '%s' requires '%s' which is not installed", ErrDependencyMissing, m, edge.To)
				}
				if !edge.SatisfiedBy(depNode.Version) {
					return nil, fmt.Errorf("%w: cannot enable %s: dependency %s version requirement not satisfied (required: %s, installed: %s)",
						ErrDependencyVersion, m, edge.To, edge.Requirement, depNode.Version)
				}
				if !depNode.Enabled && !planned[edge.To] {
					queue = append(queue, edge.To)
				}
			case TypeRecommended:
				depNode, ok := g.Node(edge.To)
				if !ok || !edge.SatisfiedBy(depNode.Version) {
					continue
				}
				if !depNode.Enabled && !planned[edge.To] {
					queue = append(queue, edge.To)
				}
			}
		}
	}
	return order, nil
}

// ValidateNoConflicts checks that none of the planned MODs conflict (via an
// incompatible edge, in either direction) with a currently-enabled MOD or
// another MOD in the same plan.
func ValidateNoConflicts(g *Graph, planned []mod.MOD) error {
	plannedSet := map[mod.MOD]bool{}
	for _, m := range planned {
		plannedSet[m] = true
	}

	for _, m := range planned {
		for _, edge := range g.EdgesFrom(m) {
			if edge.Type != TypeIncompatible {
				continue
			}
			if err := checkConflict(g, m, edge.To, plannedSet); err != nil {
				return err
			}
		}
		for _, edge := range g.EdgesTo(m) {
			if edge.Type != TypeIncompatible {
				continue
			}
			if err := checkConflict(g, m, edge.From, plannedSet); err != nil {
				return err
			}
		}
	}
	return nil
}

func checkConflict(g *Graph, m, other mod.MOD, plannedSet map[mod.MOD]bool) error {
	if node, ok := g.Node(other); ok && node.Enabled {
		return fmt.Errorf("%w: cannot enable %s: conflicts with %s which is currently enabled", ErrMODConflict, m, other)
	}
	if plannedSet[other] {
		return fmt.Errorf("%w: cannot enable %s: conflicts with %s which is also being enabled", ErrMODConflict, m, other)
	}
	return nil
}

// MarkDisabledDependenciesForEnable walks the required (and, when
// includeRecommended is true, recommended) dependencies of every node
// planned for install or enable and marks installed-but-disabled
// dependencies for enabling (recursively), so installing a MOD also turns
// its already-present dependency chain back on. Recommended dependencies
// are on by default, so they're treated the same as required ones unless
// the caller opts out via includeRecommended=false.
func MarkDisabledDependenciesForEnable(g *Graph, includeRecommended bool) {
	var queue []mod.MOD
	for _, node := range g.Nodes() {
		if node.Operation == OpInstall || node.Operation == OpEnable {
			queue = append(queue, node.MOD)
		}
	}

	processed := map[mod.MOD]bool{}
	for len(queue) > 0 {
		m := queue[0]
		queue = queue[1:]
		if processed[m] {
			continue
		}
		processed[m] = true

		for _, edge := range g.EdgesFrom(m) {
			relevant := edge.Type == TypeRequired || (includeRecommended && edge.Type == TypeRecommended)
			if !relevant {
				continue
			}
			depNode, ok := g.Node(edge.To)
			if !ok || depNode.Operation != OpNone || depNode.Enabled || !depNode.Installed {
				continue
			}
			g.SetNodeOperation(edge.To, OpEnable)
			queue = append(queue, edge.To)
		}
	}
}

// ValidateInstallGraph rejects an install plan whose graph has a
// required-dependency cycle, or where a MOD marked for install conflicts
// with a currently-enabled MOD.
func ValidateInstallGraph(g *Graph) error {
	if g.IsCyclic() {
		return fmt.Errorf("%w: circular dependency detected in MOD(s) to install", ErrCircularDependency)
	}
	for _, node := range g.Nodes() {
		if node.Operation != OpInstall {
			continue
		}
		for _, edge := range g.EdgesFrom(node.MOD) {
			if edge.Type != TypeIncompatible {
				continue
			}
			if target, ok := g.Node(edge.To); ok && target.Enabled {
				return fmt.Errorf("%w: cannot install %s: it conflicts with enabled MOD %s", ErrMODConflict, node.MOD, edge.To)
			}
		}
	}
	return nil
}

// PlanDisableAll returns every enabled MOD except base.
func PlanDisableAll(g *Graph) []mod.MOD {
	var mods []mod.MOD
	for _, node := range g.Nodes() {
		if node.Enabled && !node.MOD.IsBase() {
			mods = append(mods, node.MOD)
		}
	}
	return mods
}

// PlanDisable computes the MODs to disable when disabling targets, pulling
// in enabled dependents recursively (BFS). Targets not present in the
// graph, or already disabled, are silently skipped — the caller is
// responsible for warning about targets that are not installed.
func PlanDisable(g *Graph, targets []mod.MOD) []mod.MOD {
	planned := map[mod.MOD]bool{}
	var order []mod.MOD
	queue := append([]mod.MOD(nil), targets...)

	for len(queue) > 0 {
		m := queue[0]
		queue = queue[1:]

		node, ok := g.Node(m)
		if !ok || !node.Enabled || planned[m] {
			continue
		}
		for _, dependent := range g.FindEnabledDependents(m) {
			if !planned[dependent] {
				queue = append(queue, dependent)
			}
		}
		planned[m] = true
		order = append(order, m)
	}
	return order
}
