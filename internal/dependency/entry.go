// Package dependency parses MOD dependency strings and builds, sorts, and
// validates the dependency graph.
package dependency

import (
	"fmt"

	"github.com/sakuro/factorix/internal/mod"
)

// Type is the kind of a dependency relation.
type Type uint8

const (
	TypeRequired Type = iota
	TypeOptional
	TypeHiddenOptional
	TypeIncompatible
	TypeLoadNeutral
	TypeRecommended
)

func (t Type) String() string {
	switch t {
	case TypeRequired:
		return "required"
	case TypeOptional:
		return "optional"
	case TypeHiddenOptional:
		return "hidden"
	case TypeIncompatible:
		return "incompatible"
	case TypeLoadNeutral:
		return "load-neutral"
	case TypeRecommended:
		return "recommended"
	default:
		return fmt.Sprintf("Type(%d)", uint8(t))
	}
}

// prefix returns the dependency-string prefix for the type, including the
// separating space when non-empty.
func (t Type) prefix() string {
	switch t {
	case TypeOptional:
		return "? "
	case TypeHiddenOptional:
		return "(?) "
	case TypeIncompatible:
		return "! "
	case TypeLoadNeutral:
		return "~ "
	case TypeRecommended:
		return "+ "
	default:
		return ""
	}
}

// Operator is a version comparison operator.
type Operator uint8

const (
	OpEqual Operator = iota
	OpGreater
	OpGreaterEqual
	OpLess
	OpLessEqual
)

func (o Operator) String() string {
	switch o {
	case OpEqual:
		return "="
	case OpGreater:
		return ">"
	case OpGreaterEqual:
		return ">="
	case OpLess:
		return "<"
	case OpLessEqual:
		return "<="
	default:
		return fmt.Sprintf("Operator(%d)", uint8(o))
	}
}

// VersionRequirement is a version constraint such as ">= 1.2.0".
type VersionRequirement struct {
	Operator Operator
	Version  mod.MODVersion
}

// SatisfiedBy reports whether the given version satisfies the requirement.
func (r VersionRequirement) SatisfiedBy(v mod.MODVersion) bool {
	c := v.Compare(r.Version)
	switch r.Operator {
	case OpEqual:
		return c == 0
	case OpGreater:
		return c > 0
	case OpGreaterEqual:
		return c >= 0
	case OpLess:
		return c < 0
	case OpLessEqual:
		return c <= 0
	default:
		return false
	}
}

func (r VersionRequirement) String() string {
	return fmt.Sprintf("%s %s", r.Operator, r.Version)
}

// Entry is a single parsed dependency of a MOD.
type Entry struct {
	MOD         mod.MOD
	Type        Type
	Requirement *VersionRequirement // nil when no version constraint
}

// IsOptional reports whether the dependency is optional, including the
// hidden-optional form.
func (e Entry) IsOptional() bool {
	return e.Type == TypeOptional || e.Type == TypeHiddenOptional
}

// SatisfiedBy reports whether the given version satisfies the entry's
// version requirement; entries without a requirement are always satisfied.
func (e Entry) SatisfiedBy(v mod.MODVersion) bool {
	if e.Requirement == nil {
		return true
	}
	return e.Requirement.SatisfiedBy(v)
}

// String renders the entry in dependency-string form, e.g. "? some-mod >= 1.2.0".
func (e Entry) String() string {
	s := e.Type.prefix() + e.MOD.Name
	if e.Requirement != nil {
		s += " " + e.Requirement.String()
	}
	return s
}
