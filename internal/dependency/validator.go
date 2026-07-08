package dependency

import (
	"fmt"
	"strings"

	"github.com/sakuro/factorix/internal/mod"
)

// Validator checks a dependency graph for missing or disabled dependencies,
// unsatisfied version requirements, conflicts, cycles, and inconsistencies
// between the graph and mod-list.json.
type Validator struct {
	Graph         *Graph
	MODList       *mod.MODList
	InstalledMODs []mod.InstalledMOD
}

// Validate runs all checks and collects the findings.
func (v *Validator) Validate() *ValidationResult {
	result := &ValidationResult{}
	v.validateCircularDependencies(result)
	v.validateDependencies(result)
	v.validateConflicts(result)
	v.validateMODList(result)
	return result
}

func (v *Validator) validateCircularDependencies(result *ValidationResult) {
	if !v.Graph.IsCyclic() {
		return
	}
	for _, component := range v.Graph.StronglyConnectedComponents() {
		if len(component) <= 1 {
			continue
		}
		names := make([]string, len(component))
		for i, m := range component {
			names[i] = m.Name
		}
		result.Errors = append(result.Errors, ValidationError{
			Type:    ErrorCircularDependency,
			Message: "Circular dependency detected: " + strings.Join(names, " -> "),
		})
	}
}

func (v *Validator) validateDependencies(result *ValidationResult) {
	for _, node := range v.Graph.Nodes() {
		if !node.Enabled {
			continue
		}
		for _, edge := range v.Graph.EdgesFrom(node.MOD) {
			if edge.Type != TypeRequired {
				continue
			}
			v.validateRequiredDependency(node, edge, result)
		}
	}
}

func (v *Validator) validateRequiredDependency(node Node, edge Edge, result *ValidationResult) {
	depNode, ok := v.Graph.Node(edge.To)
	if !ok {
		result.Errors = append(result.Errors, ValidationError{
			Type:       ErrorMissingDependency,
			Message:    fmt.Sprintf("MOD '%s@%s' requires '%s' which is not installed", node.MOD, node.Version, edge.To),
			MOD:        node.MOD,
			Dependency: edge.To,
		})
		return
	}
	if !depNode.Enabled {
		result.Errors = append(result.Errors, ValidationError{
			Type:       ErrorDisabledDependency,
			Message:    fmt.Sprintf("MOD '%s@%s' requires '%s' which is not enabled", node.MOD, node.Version, edge.To),
			MOD:        node.MOD,
			Dependency: edge.To,
		})
		return
	}
	if edge.SatisfiedBy(depNode.Version) {
		return
	}
	result.Errors = append(result.Errors, ValidationError{
		Type: ErrorVersionMismatch,
		Message: fmt.Sprintf("MOD '%s@%s' requires '%s' version %s, but version %s is installed",
			node.MOD, node.Version, edge.To, edge.Requirement, depNode.Version),
		MOD:        node.MOD,
		Dependency: edge.To,
	})
	v.suggestAlternativeVersions(edge, result)
}

func (v *Validator) validateConflicts(result *ValidationResult) {
	for _, node := range v.Graph.Nodes() {
		if !node.Enabled {
			continue
		}
		for _, edge := range v.Graph.EdgesFrom(node.MOD) {
			if edge.Type != TypeIncompatible {
				continue
			}
			conflictNode, ok := v.Graph.Node(edge.To)
			if !ok || !conflictNode.Enabled {
				continue
			}
			result.Errors = append(result.Errors, ValidationError{
				Type: ErrorConflict,
				Message: fmt.Sprintf("MOD '%s@%s' conflicts with '%s@%s' but both are enabled",
					node.MOD, node.Version, edge.To, conflictNode.Version),
				MOD:        node.MOD,
				Dependency: edge.To,
			})
		}
	}
}

func (v *Validator) validateMODList(result *ValidationResult) {
	for m := range v.MODList.MODs() {
		if v.Graph.Contains(m) {
			continue
		}
		result.Warnings = append(result.Warnings, ValidationWarning{
			Type:    WarningMODInListNotInstalled,
			Message: fmt.Sprintf("MOD '%s' in mod-list.json is not installed", m),
			MOD:     m,
		})
	}
	for _, node := range v.Graph.Nodes() {
		if v.MODList.Contains(node.MOD) {
			continue
		}
		result.Warnings = append(result.Warnings, ValidationWarning{
			Type:    WarningMODInstalledNotInList,
			Message: fmt.Sprintf("MOD '%s' is installed but not in mod-list.json", node.MOD),
			MOD:     node.MOD,
		})
	}
}

// suggestAlternativeVersions points out installed versions that would
// satisfy the failed requirement.
func (v *Validator) suggestAlternativeVersions(edge Edge, result *ValidationResult) {
	for _, im := range v.InstalledMODs {
		if im.MOD != edge.To || !edge.SatisfiedBy(im.Version) {
			continue
		}
		result.Suggestions = append(result.Suggestions, Suggestion{
			Message: fmt.Sprintf("MOD '%s' version %s is installed and would satisfy this requirement",
				edge.To, im.Version),
			MOD:     edge.To,
			Version: im.Version,
		})
	}
}
