package serdes

import (
	"errors"
	"fmt"
)

var (
	ErrInvalidLength = errors.New("invalid length")
	ErrInvalidUTF8   = errors.New("string is not valid UTF-8")
)

// UnknownPropertyTypeError reports a property tree type byte outside the
// known range.
type UnknownPropertyTypeError struct {
	Type uint8
}

func (e *UnknownPropertyTypeError) Error() string {
	return fmt.Sprintf("unknown property type: %d", e.Type)
}
