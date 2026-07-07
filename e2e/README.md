# End-to-End Test Cases

Language-neutral CLI test cases. Each case describes a `factorix` invocation and
its expected observable behavior (stdout and exit status). The cases are plain
data; a thin per-language driver executes them — currently RSpec
(`spec/e2e/`), later a Go test driver running the same cases against the Go
binary (see `doc/go-migration-roadmap.md`).

stderr is not compared: it carries progress reporting and is not part of the
stable CLI contract.

## Layout

```
e2e/cases/<group>/<name>/
├── case.yaml            # the case definition
├── files/               # files copied into the sandbox (optional)
└── expected_stdout.txt  # expected output (optional; referenced from case.yaml)
```

## case.yaml

```yaml
command: [mod, list]        # argv passed to factorix (required)
stdin: "..."                # standard input (optional)
config:                     # Factorix configuration (optional)
  runtime:
    user_dir: "{{SANDBOX}}/factorio"
    data_dir: "{{SANDBOX}}/factorio/data"
dirs:                       # empty directories to create in the sandbox (optional)
  - factorio/data
files:                      # files to place in the sandbox (optional)
  - {from: files/mod-list.json, to: factorio/mods/mod-list.json}
  - {from: //spec/fixtures/changelog/basic.txt, to: cwd/changelog.txt}
expect:
  status: 0                 # expected exit status (required)
  stdout:                   # one of: (omit to skip stdout assertion)
    file: expected_stdout.txt   # exact match against this file's content
    # match: "^\\d+\\.\\d+\\.\\d+$"  # or: regex match (multiline mode)
```

- `command`: argv after the `factorix` executable name.
- `config`: nested key-value settings. The driver renders them into the config
  format of the implementation under test (Ruby DSL today, TOML later) and
  points `FACTORIX_CONFIG` at the rendered file. Keys mirror the configuration
  structure (`runtime.user_dir`, `log_level`, …).
- `files[].from`: source path — relative to the case directory, or repository
  root when prefixed with `//`.
- `files[].to`: destination relative to the sandbox root. The process working
  directory is `<sandbox>/cwd/`, so files the command should find in its working
  directory go under `cwd/`.
- `expect.stdout.file` content and `config`/`files[].to` values may contain
  `{{SANDBOX}}`, replaced with the absolute sandbox root path.

## Execution contract (what a driver must implement)

1. Create a fresh temporary directory per case (the sandbox) containing `cwd/`,
   `xdg-cache/`, `xdg-config/`, and `xdg-state/`.
2. Copy `files` entries into place, creating intermediate directories.
3. If `config` is present, render it and set `FACTORIX_CONFIG` to the result.
4. Run the binary with `cwd/` as the working directory and this environment:
   `NO_COLOR=1`, `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME` pointing
   into the sandbox.
5. Feed `stdin` (empty when omitted); capture stdout and exit status.
6. Assert exit status; assert stdout after `{{SANDBOX}}` substitution
   (exact for `file`, regex for `match`).
