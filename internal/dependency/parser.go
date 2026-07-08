package dependency

import (
	"strings"

	"github.com/sakuro/factorix/internal/mod"
)

// MOD names and the grammar are ASCII; matching Unicode whitespace would be
// broader than the Ruby grammar's \s.
const asciiSpaces = " \t\r\n\f\v"

// Prefixes are matched longest first so "(?)" is not read as "(" + "?".
var prefixes = []struct {
	token string
	typ   Type
}{
	{"(?)", TypeHiddenOptional},
	{"!", TypeIncompatible},
	{"?", TypeOptional},
	{"~", TypeLoadNeutral},
	{"+", TypeRecommended},
}

// Operators are matched longest first so ">=" is not read as ">" + "=".
var operators = []struct {
	token string
	op    Operator
}{
	{">=", OpGreaterEqual},
	{"<=", OpLessEqual},
	{">", OpGreater},
	{"<", OpLess},
	{"=", OpEqual},
}

// Parse parses a dependency string from info.json:
//
//	dep    = [prefix] name [op version]
//	prefix = "!" | "?" | "(?)" | "~" | "+"
//	op     = "=" | ">" | ">=" | "<" | "<="
//
// MOD names may contain spaces, so the scanner treats a space run as part of
// the name only when another name character follows it.
func Parse(s string) (Entry, error) {
	rest := trimSpaces(s)
	if rest == "" {
		return Entry{}, &ParseError{Input: s, Reason: "empty dependency string"}
	}

	typ := TypeRequired
	for _, p := range prefixes {
		if strings.HasPrefix(rest, p.token) {
			typ = p.typ
			rest = trimSpaces(rest[len(p.token):])
			break
		}
	}

	name, rest, err := scanName(rest, s)
	if err != nil {
		return Entry{}, err
	}
	entry := Entry{MOD: mod.MOD{Name: name}, Type: typ}
	if rest == "" {
		return entry, nil
	}

	op, rest, ok := scanOperator(rest)
	if !ok {
		return Entry{}, &ParseError{Input: s, Reason: "expected a version operator after the MOD name"}
	}
	if rest == "" {
		return Entry{}, &ParseError{Input: s, Reason: "empty version"}
	}
	if !isVersionFormat(rest) {
		return Entry{}, &ParseError{Input: s, Reason: "invalid version format"}
	}

	version, err := mod.ParseMODVersion(rest)
	if err != nil {
		// The format is valid, so the error is an out-of-range component.
		// MODs with such versions exist on the Portal; drop the requirement
		// instead of failing, matching the Ruby implementation.
		return entry, nil
	}
	entry.Requirement = &VersionRequirement{Operator: op, Version: version}
	return entry, nil
}

func isNameChar(c byte) bool {
	return c == '_' || c == '-' ||
		('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z') || ('0' <= c && c <= '9')
}

func isSpaceChar(c byte) bool {
	return strings.IndexByte(asciiSpaces, c) >= 0
}

func trimSpaces(s string) string {
	return strings.Trim(s, asciiSpaces)
}

// scanName returns the MOD name and the remaining input after it.
func scanName(s, input string) (name, rest string, err error) {
	if s == "" || !isNameChar(s[0]) {
		return "", "", &ParseError{Input: input, Reason: "empty MOD name"}
	}

	end := 0 // exclusive end of the name
	for i := 0; i < len(s); {
		switch {
		case isNameChar(s[i]):
			i++
			end = i
		case isSpaceChar(s[i]):
			j := i
			for j < len(s) && isSpaceChar(s[j]) {
				j++
			}
			if j < len(s) && isNameChar(s[j]) {
				i = j
				continue
			}
			return s[:end], trimSpaces(s[end:]), nil
		default:
			return s[:end], trimSpaces(s[end:]), nil
		}
	}
	return s[:end], "", nil
}

func scanOperator(s string) (Operator, string, bool) {
	for _, o := range operators {
		if strings.HasPrefix(s, o.token) {
			return o.op, trimSpaces(s[len(o.token):]), true
		}
	}
	return 0, s, false
}

// isVersionFormat reports whether s is "X.Y" or "X.Y.Z" with decimal parts.
func isVersionFormat(s string) bool {
	parts := strings.Split(s, ".")
	if len(parts) != 2 && len(parts) != 3 {
		return false
	}
	for _, part := range parts {
		if part == "" {
			return false
		}
		for i := 0; i < len(part); i++ {
			if part[i] < '0' || part[i] > '9' {
				return false
			}
		}
	}
	return true
}
