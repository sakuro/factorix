// Package e2e runs the language-neutral CLI cases (see README.md) against
// the Go binary, implementing the execution contract the Ruby driver
// (spec/e2e/runner.rb) also follows.
package e2e

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/BurntSushi/toml"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

const sandboxPlaceholder = "{{SANDBOX}}"

// binaryPath is the factorix binary under test, built once in TestMain.
var binaryPath string

func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "factorix-e2e-bin")
	if err != nil {
		panic(err)
	}
	defer os.RemoveAll(dir)

	binaryPath = filepath.Join(dir, "factorix")
	// Release binaries get the real version from goreleaser's ldflags; the
	// version case only asserts that a semver line reaches stdout.
	build := exec.Command("go", "build",
		"-ldflags", "-X github.com/sakuro/factorix/internal/cli.Version=0.0.0",
		"-o", binaryPath, "../cmd/factorix")
	build.Stderr = os.Stderr
	if err := build.Run(); err != nil {
		panic(fmt.Sprintf("building factorix: %s", err))
	}

	os.Exit(m.Run())
}

type caseDefinition struct {
	Command []string       `yaml:"command"`
	Stdin   string         `yaml:"stdin"`
	Config  map[string]any `yaml:"config"`
	Dirs    []string       `yaml:"dirs"`
	Files   []struct {
		From string `yaml:"from"`
		To   string `yaml:"to"`
	} `yaml:"files"`
	Expect struct {
		Status int `yaml:"status"`
		Stdout *struct {
			File  string `yaml:"file"`
			Match string `yaml:"match"`
		} `yaml:"stdout"`
	} `yaml:"expect"`
}

func TestCases(t *testing.T) {
	repoRoot, err := filepath.Abs("..")
	require.NoError(t, err)

	caseFiles, err := filepath.Glob(filepath.Join("cases", "*", "*", "case.yaml"))
	require.NoError(t, err)
	require.NotEmpty(t, caseFiles)

	for _, caseFile := range caseFiles {
		caseDir := filepath.Dir(caseFile)
		name := strings.TrimPrefix(filepath.ToSlash(caseDir), "cases/")
		t.Run(name, func(t *testing.T) {
			runCase(t, repoRoot, caseDir)
		})
	}
}

func runCase(t *testing.T, repoRoot, caseDir string) {
	data, err := os.ReadFile(filepath.Join(caseDir, "case.yaml"))
	require.NoError(t, err)
	var definition caseDefinition
	require.NoError(t, yaml.Unmarshal(data, &definition))

	sandbox := t.TempDir()
	substitute := func(text string) string {
		return strings.ReplaceAll(text, sandboxPlaceholder, sandbox)
	}

	for _, name := range []string{"cwd", "xdg-cache", "xdg-config", "xdg-data", "xdg-state"} {
		require.NoError(t, os.MkdirAll(filepath.Join(sandbox, name), 0o755))
	}
	for _, dir := range definition.Dirs {
		require.NoError(t, os.MkdirAll(filepath.Join(sandbox, dir), 0o755))
	}

	for _, file := range definition.Files {
		source := filepath.Join(caseDir, file.From)
		if after, isRepoRelative := strings.CutPrefix(file.From, "//"); isRepoRelative {
			source = filepath.Join(repoRoot, after)
		}
		destination := filepath.Join(sandbox, substitute(file.To))
		require.NoError(t, os.MkdirAll(filepath.Dir(destination), 0o755))
		require.NoError(t, copyTree(source, destination))
	}

	env := environWithout("NO_COLOR", "FACTORIX_CONFIG", "XDG_CACHE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME")
	env = append(env,
		"NO_COLOR=1",
		"XDG_CACHE_HOME="+filepath.Join(sandbox, "xdg-cache"),
		"XDG_CONFIG_HOME="+filepath.Join(sandbox, "xdg-config"),
		"XDG_DATA_HOME="+filepath.Join(sandbox, "xdg-data"),
		"XDG_STATE_HOME="+filepath.Join(sandbox, "xdg-state"),
	)
	if definition.Config != nil {
		configPath := filepath.Join(sandbox, "config.toml")
		var rendered bytes.Buffer
		require.NoError(t, toml.NewEncoder(&rendered).Encode(substituteValues(definition.Config, substitute)))
		require.NoError(t, os.WriteFile(configPath, rendered.Bytes(), 0o644))
		env = append(env, "FACTORIX_CONFIG="+configPath)
	}

	cmd := exec.Command(binaryPath, definition.Command...)
	cmd.Dir = filepath.Join(sandbox, "cwd")
	cmd.Env = env
	cmd.Stdin = strings.NewReader(definition.Stdin)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err = cmd.Run()
	exitStatus := 0
	if err != nil {
		var exitErr *exec.ExitError
		require.ErrorAs(t, err, &exitErr, "factorix did not run")
		exitStatus = exitErr.ExitCode()
	}

	assert.Equal(t, definition.Expect.Status, exitStatus,
		"exit status\nstdout:\n%s\nstderr:\n%s", stdout.String(), stderr.String())

	stdoutExpectation := definition.Expect.Stdout
	if stdoutExpectation == nil {
		return
	}
	switch {
	case stdoutExpectation.File != "":
		expected, err := os.ReadFile(filepath.Join(caseDir, stdoutExpectation.File))
		require.NoError(t, err)
		assert.Equal(t, substitute(string(expected)), stdout.String())
	case stdoutExpectation.Match != "":
		// (?m) gives ^ and $ Ruby's always-per-line semantics.
		pattern := regexp.MustCompile("(?m)" + stdoutExpectation.Match)
		assert.Regexp(t, pattern, stdout.String())
	}
}

// copyTree copies a file, or a directory recursively (FileUtils.cp_r).
func copyTree(source, destination string) error {
	info, err := os.Stat(source)
	if err != nil {
		return err
	}
	if info.IsDir() {
		return os.CopyFS(destination, os.DirFS(source))
	}
	data, err := os.ReadFile(source)
	if err != nil {
		return err
	}
	return os.WriteFile(destination, data, 0o644)
}

func environWithout(names ...string) []string {
	var env []string
	for _, entry := range os.Environ() {
		name, _, _ := strings.Cut(entry, "=")
		if !slices.Contains(names, name) {
			env = append(env, entry)
		}
	}
	return env
}

func substituteValues(value map[string]any, substitute func(string) string) map[string]any {
	result := make(map[string]any, len(value))
	for key, val := range value {
		switch typed := val.(type) {
		case map[string]any:
			result[key] = substituteValues(typed, substitute)
		case string:
			result[key] = substitute(typed)
		default:
			result[key] = val
		}
	}
	return result
}
