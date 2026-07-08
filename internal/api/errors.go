package api

import "errors"

var (
	ErrMODNotOnPortal  = errors.New("MOD not found on portal")
	ErrCredential      = errors.New("credential error")
	ErrInvalidArgument = errors.New("invalid argument")
	ErrInvalidResponse = errors.New("invalid API response")
)
