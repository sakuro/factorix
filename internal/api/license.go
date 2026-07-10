package api

import (
	"regexp"
	"slices"
)

// licenseIdentifiers are the standard license identifiers accepted by the
// portal's edit_details API.
//
// See https://wiki.factorio.com/Mod_details_API#License
var licenseIdentifiers = []string{
	"default_mit",
	"default_gnugplv3",
	"default_gnulgplv3",
	"default_mozilla2",
	"default_apache2",
	"default_unlicense",
}

// Custom license identifiers are "custom_" + 24 lowercase hex chars.
var customLicensePattern = regexp.MustCompile(`\Acustom_[0-9a-f]{24}\z`)

// LicenseIdentifiers returns the standard license identifiers.
func LicenseIdentifiers() []string {
	return slices.Clone(licenseIdentifiers)
}

// ValidLicenseIdentifier reports whether the value is a standard or custom
// license identifier.
func ValidLicenseIdentifier(value string) bool {
	return slices.Contains(licenseIdentifiers, value) || customLicensePattern.MatchString(value)
}
