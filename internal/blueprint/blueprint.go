// Package blueprint encodes and decodes Factorio blueprint strings
// (a version byte followed by Base64-encoded zlib-compressed JSON).
package blueprint

import (
	"bytes"
	"compress/zlib"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
)

// The only supported version byte.
const supportedVersion = '0'

var (
	ErrUnsupportedVersion = errors.New("unsupported blueprint version")
	ErrFormat             = errors.New("invalid blueprint")
)

// Blueprint holds the blueprint's JSON. The original text is kept as-is so
// key order survives a decode/encode round trip.
type Blueprint struct {
	json []byte
}

// Decode parses a blueprint string.
func Decode(s string) (*Blueprint, error) {
	if len(s) == 0 || s[0] != supportedVersion {
		version := "(empty)"
		if len(s) > 0 {
			version = string(s[0])
		}
		return nil, fmt.Errorf("%w: %s", ErrUnsupportedVersion, version)
	}

	compressed, err := base64.StdEncoding.DecodeString(s[1:])
	if err != nil {
		return nil, fmt.Errorf("%w: invalid Base64 encoding: %s", ErrFormat, err)
	}
	r, err := zlib.NewReader(bytes.NewReader(compressed))
	if err != nil {
		return nil, fmt.Errorf("%w: invalid zlib data: %s", ErrFormat, err)
	}
	defer r.Close()
	jsonData, err := io.ReadAll(r)
	if err != nil {
		return nil, fmt.Errorf("%w: invalid zlib data: %s", ErrFormat, err)
	}
	return FromJSON(jsonData)
}

// FromJSON builds a Blueprint from JSON content.
func FromJSON(data []byte) (*Blueprint, error) {
	if !json.Valid(data) {
		return nil, fmt.Errorf("%w: invalid JSON", ErrFormat)
	}
	return &Blueprint{json: data}, nil
}

// Encode renders the blueprint string.
func (b *Blueprint) Encode() (string, error) {
	var compact bytes.Buffer
	if err := json.Compact(&compact, b.json); err != nil {
		return "", fmt.Errorf("%w: %s", ErrFormat, err)
	}

	var compressed bytes.Buffer
	w, err := zlib.NewWriterLevel(&compressed, zlib.BestCompression)
	if err != nil {
		return "", err
	}
	if _, err := w.Write(compact.Bytes()); err != nil {
		return "", err
	}
	if err := w.Close(); err != nil {
		return "", err
	}
	return string(supportedVersion) + base64.StdEncoding.EncodeToString(compressed.Bytes()), nil
}

// JSON renders the blueprint content as pretty-printed JSON, preserving the
// original key order.
func (b *Blueprint) JSON() ([]byte, error) {
	var pretty bytes.Buffer
	if err := json.Indent(&pretty, b.json, "", "  "); err != nil {
		return nil, err
	}
	return pretty.Bytes(), nil
}
