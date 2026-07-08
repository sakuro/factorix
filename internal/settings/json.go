package settings

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"slices"
	"strconv"
	"strings"

	"github.com/sakuro/factorix/internal/mod"
	"github.com/sakuro/factorix/internal/serdes"
)

// DumpJSON renders the settings as pretty-printed JSON:
// {"game_version": "X.Y.Z", "<section>": {"<key>": <value>, ...}, ...}.
// Empty sections are omitted, matching the Ruby implementation.
func (ms *MODSettings) DumpJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteString("{\n")
	fmt.Fprintf(&buf, "  %s: %s", jsonString("game_version"), jsonString(ms.GameVersion.String()))

	for section := range ms.Sections() {
		if section.Len() == 0 {
			continue
		}
		fmt.Fprintf(&buf, ",\n  %s: ", jsonString(section.Name()))
		entries := make([]serdes.DictEntry, 0, section.Len())
		for key, value := range section.All() {
			entries = append(entries, serdes.DictEntry{Key: key, Value: value})
		}
		if err := appendJSONValue(&buf, serdes.Dict(entries...), "  "); err != nil {
			return nil, err
		}
	}

	buf.WriteString("\n}")
	return buf.Bytes(), nil
}

func appendJSONValue(buf *bytes.Buffer, value serdes.PropertyTree, indent string) error {
	switch value.Kind {
	case serdes.KindNone:
		buf.WriteString("null")
	case serdes.KindBool:
		v, _ := value.Bool()
		buf.WriteString(strconv.FormatBool(v))
	case serdes.KindNumber:
		v, _ := value.Number()
		s, err := formatDouble(v)
		if err != nil {
			return err
		}
		buf.WriteString(s)
	case serdes.KindString:
		v, _ := value.Str()
		buf.WriteString(jsonString(v))
	case serdes.KindSignedInt:
		v, _ := value.SignedInt()
		buf.WriteString(strconv.FormatInt(v, 10))
	case serdes.KindUnsignedInt:
		v, _ := value.UnsignedInt()
		buf.WriteString(strconv.FormatUint(v, 10))
	case serdes.KindList:
		items, _ := value.List()
		if len(items) == 0 {
			buf.WriteString("[]")
			return nil
		}
		buf.WriteString("[\n")
		inner := indent + "  "
		for i, item := range items {
			if i > 0 {
				buf.WriteString(",\n")
			}
			buf.WriteString(inner)
			if err := appendJSONValue(buf, item, inner); err != nil {
				return err
			}
		}
		buf.WriteString("\n" + indent + "]")
	case serdes.KindDict:
		entries, _ := value.Dict()
		if len(entries) == 0 {
			buf.WriteString("{}")
			return nil
		}
		buf.WriteString("{\n")
		inner := indent + "  "
		for i, entry := range entries {
			if i > 0 {
				buf.WriteString(",\n")
			}
			buf.WriteString(inner + jsonString(entry.Key) + ": ")
			if err := appendJSONValue(buf, entry.Value, inner); err != nil {
				return err
			}
		}
		buf.WriteString("\n" + indent + "}")
	default:
		return &serdes.UnknownPropertyTypeError{Type: uint8(value.Kind)}
	}
	return nil
}

// A JSON number must keep the decimal point (e.g. "100.0", not "100") so
// that RestoreJSON maps it back to Number rather than SignedInt.
func formatDouble(v float64) (string, error) {
	if math.IsNaN(v) || math.IsInf(v, 0) {
		return "", fmt.Errorf("%w: %v is not representable in JSON", ErrMalformedSettings, v)
	}
	s := strconv.FormatFloat(v, 'g', -1, 64)
	if !strings.ContainsAny(s, ".eE") {
		s += ".0"
	}
	return s, nil
}

func jsonString(s string) string {
	b, err := json.Marshal(s)
	if err != nil {
		// json.Marshal of a string cannot fail; invalid UTF-8 is replaced.
		return `""`
	}
	return string(b)
}

// RestoreJSON parses JSON produced by DumpJSON back into MODSettings.
// Sections are rebuilt in canonical order; keys keep their JSON order.
// JSON cannot distinguish signed from unsigned, so every integer becomes
// SignedInt, matching Factorio's int-setting type and the Ruby implementation.
func RestoreJSON(data []byte) (*MODSettings, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()

	if err := expectDelim(dec, '{'); err != nil {
		return nil, err
	}

	var version *mod.GameVersion
	parsed := map[string]*Section{}

	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil, err
		}
		key, ok := tok.(string)
		if !ok {
			return nil, fmt.Errorf("%w: unexpected token %v", ErrMalformedSettings, tok)
		}

		switch {
		case key == "game_version":
			value, err := parseJSONValue(dec)
			if err != nil {
				return nil, err
			}
			s, ok := value.Str()
			if !ok {
				return nil, fmt.Errorf("%w: game_version is not a string", ErrMalformedSettings)
			}
			v, err := mod.ParseGameVersion(s)
			if err != nil {
				return nil, err
			}
			version = &v
		case slices.Contains(ValidSections, key):
			value, err := parseJSONValue(dec)
			if err != nil {
				return nil, err
			}
			entries, ok := value.Dict()
			if !ok {
				return nil, fmt.Errorf("%w: section %q is not an object", ErrMalformedSettings, key)
			}
			section, _ := NewSection(key)
			for _, entry := range entries {
				section.Set(entry.Key, entry.Value)
			}
			parsed[key] = section
		default:
			// Unknown top-level keys are ignored, as in the Ruby implementation.
			if _, err := parseJSONValue(dec); err != nil {
				return nil, err
			}
		}
	}
	if err := expectDelim(dec, '}'); err != nil {
		return nil, err
	}

	if version == nil {
		return nil, fmt.Errorf("%w: game_version is missing", ErrMalformedSettings)
	}

	ms := New(*version)
	for name, section := range parsed {
		ms.sections[name] = section
	}
	return ms, nil
}

// parseJSONValue reads one JSON value as a PropertyTree via the token
// stream, preserving object key order (a decoded map would lose it).
func parseJSONValue(dec *json.Decoder) (serdes.PropertyTree, error) {
	tok, err := dec.Token()
	if err != nil {
		return serdes.PropertyTree{}, err
	}
	return jsonTokenToTree(dec, tok)
}

func jsonTokenToTree(dec *json.Decoder, tok json.Token) (serdes.PropertyTree, error) {
	switch t := tok.(type) {
	case nil:
		return serdes.None(), nil
	case bool:
		return serdes.Bool(t), nil
	case string:
		return serdes.String(t), nil
	case json.Number:
		if strings.ContainsAny(t.String(), ".eE") {
			v, err := t.Float64()
			if err != nil {
				return serdes.PropertyTree{}, err
			}
			return serdes.Number(v), nil
		}
		v, err := t.Int64()
		if err != nil {
			return serdes.PropertyTree{}, err
		}
		return serdes.SignedInt(v), nil
	case json.Delim:
		switch t {
		case '{':
			var entries []serdes.DictEntry
			for dec.More() {
				keyTok, err := dec.Token()
				if err != nil {
					return serdes.PropertyTree{}, err
				}
				key, ok := keyTok.(string)
				if !ok {
					return serdes.PropertyTree{}, fmt.Errorf("%w: unexpected token %v", ErrMalformedSettings, keyTok)
				}
				value, err := parseJSONValue(dec)
				if err != nil {
					return serdes.PropertyTree{}, err
				}
				entries = append(entries, serdes.DictEntry{Key: key, Value: value})
			}
			if err := expectDelim(dec, '}'); err != nil {
				return serdes.PropertyTree{}, err
			}
			return serdes.Dict(entries...), nil
		case '[':
			var items []serdes.PropertyTree
			for dec.More() {
				item, err := parseJSONValue(dec)
				if err != nil {
					return serdes.PropertyTree{}, err
				}
				items = append(items, item)
			}
			if err := expectDelim(dec, ']'); err != nil {
				return serdes.PropertyTree{}, err
			}
			return serdes.List(items...), nil
		default:
			return serdes.PropertyTree{}, fmt.Errorf("%w: unexpected delimiter %v", ErrMalformedSettings, t)
		}
	default:
		return serdes.PropertyTree{}, fmt.Errorf("%w: unexpected token %v", ErrMalformedSettings, tok)
	}
}

func expectDelim(dec *json.Decoder, want json.Delim) error {
	tok, err := dec.Token()
	if err != nil {
		if errors.Is(err, io.EOF) {
			return fmt.Errorf("%w: unexpected end of JSON", ErrMalformedSettings)
		}
		return err
	}
	if d, ok := tok.(json.Delim); !ok || d != want {
		return fmt.Errorf("%w: expected %q, got %v", ErrMalformedSettings, want, tok)
	}
	return nil
}
