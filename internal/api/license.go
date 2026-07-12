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

// standardLicenses is the catalog of standard license identifiers, mirroring
// Ruby's Factorix::API::License flyweight instances (lib/factorix/api/license.rb
// on the ruby branch) field for field.
var standardLicenses = map[string]License{
	"default_mit": {
		ID: "default_mit", Name: "MIT", Title: "MIT License",
		Description: "A permissive license that is short and to the point. It lets people do anything with your code with proper attribution and without warranty.",
		URL:         "https://raw.githubusercontent.com/spdx/license-list-data/main/text/MIT.txt",
	},
	"default_gnugplv3": {
		ID: "default_gnugplv3", Name: "GNU GPLv3", Title: "GNU General Public License v3.0",
		Description: "The GNU GPL is the most widely used free software license and has a strong copyleft requirement.",
		URL:         "https://raw.githubusercontent.com/spdx/license-list-data/main/text/GPL-3.0-or-later.txt",
	},
	"default_gnulgplv3": {
		ID: "default_gnulgplv3", Name: "GNU LGPLv3", Title: "GNU Lesser General Public License v3.0",
		Description: "Version 3 of the GNU LGPL is an additional set of permissions to the GNU GPLv3 license that requires derived works use the same license.",
		URL:         "https://raw.githubusercontent.com/spdx/license-list-data/main/text/LGPL-3.0-or-later.txt",
	},
	"default_mozilla2": {
		ID: "default_mozilla2", Name: "Mozilla Public License 2.0", Title: "Mozilla Public License Version 2.0",
		Description: "The Mozilla Public License (MPL 2.0) attempts to be a compromise between the permissive BSD license and the reciprocal GPL license.",
		URL:         "https://raw.githubusercontent.com/spdx/license-list-data/main/text/MPL-2.0.txt",
	},
	"default_apache2": {
		ID: "default_apache2", Name: "Apache License 2.0", Title: "Apache License, Version 2.0",
		Description: "A permissive license that also provides an express grant of patent rights from contributors to users.",
		URL:         "https://raw.githubusercontent.com/spdx/license-list-data/main/text/Apache-2.0.txt",
	},
	"default_unlicense": {
		ID: "default_unlicense", Name: "The Unlicense", Title: "The Unlicense",
		Description: "The Unlicense is a template to waive copyright interest in software and dedicate it to the public domain.",
		URL:         "https://raw.githubusercontent.com/spdx/license-list-data/main/text/Unlicense.txt",
	},
}

// StandardLicenses returns the catalog of standard licenses, ordered as in
// LicenseIdentifiers.
func StandardLicenses() []License {
	result := make([]License, len(licenseIdentifiers))
	for i, id := range licenseIdentifiers {
		result[i] = standardLicenses[id]
	}
	return result
}

// StandardLicenseFor returns the catalog entry for a standard license
// identifier. ok is false for custom or unrecognized identifiers.
func StandardLicenseFor(id string) (license License, ok bool) {
	license, ok = standardLicenses[id]
	return license, ok
}
