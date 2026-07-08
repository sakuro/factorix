package settings

import "errors"

var (
	ErrInvalidSectionName = errors.New("invalid MOD section name")
	ErrSectionNotFound    = errors.New("MOD section not found")
	ErrExtraData          = errors.New("extra data found at the end of MOD settings file")
	ErrMalformedSettings  = errors.New("malformed MOD settings")
)
