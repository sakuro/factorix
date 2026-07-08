package dependency

import (
	"errors"
	"fmt"
)

var (
	ErrNodeExists         = errors.New("node already exists")
	ErrNodeMissing        = errors.New("node does not exist")
	ErrCircularDependency = errors.New("circular dependency detected")
)

// ParseError reports a malformed dependency string.
type ParseError struct {
	Input  string
	Reason string
}

func (e *ParseError) Error() string {
	return fmt.Sprintf("invalid dependency %q: %s", e.Input, e.Reason)
}
