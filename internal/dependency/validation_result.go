package dependency

import "github.com/sakuro/factorix/internal/mod"

// ErrorType classifies validation errors.
type ErrorType uint8

const (
	ErrorMissingDependency ErrorType = iota
	ErrorDisabledDependency
	ErrorVersionMismatch
	ErrorConflict
	ErrorCircularDependency
)

// WarningType classifies validation warnings.
type WarningType uint8

const (
	WarningMODInListNotInstalled WarningType = iota
	WarningMODInstalledNotInList
	WarningRecommendedDependencyDisabled
)

// ValidationError is an error found during dependency validation.
type ValidationError struct {
	Type       ErrorType
	Message    string
	MOD        mod.MOD
	Dependency mod.MOD
}

// ValidationWarning is a warning found during dependency validation.
type ValidationWarning struct {
	Type    WarningType
	Message string
	MOD     mod.MOD
}

// Suggestion is a hint for resolving a validation error.
type Suggestion struct {
	Message string
	MOD     mod.MOD
	Version mod.MODVersion
}

// ValidationResult holds everything found during a validation pass.
type ValidationResult struct {
	Errors      []ValidationError
	Warnings    []ValidationWarning
	Suggestions []Suggestion
}

// Valid reports whether the validation found no errors.
func (r *ValidationResult) Valid() bool {
	return len(r.Errors) == 0
}
