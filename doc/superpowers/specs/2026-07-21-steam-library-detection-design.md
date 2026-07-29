# Steam Library-Based Factorio Detection

## Goal

`internal/platform` currently hardcodes the Factorio installation path under
each OS's default Steam library (e.g. `~/.steam/steam/steamapps/common/Factorio`
on Linux, `%ProgramFiles(x86)%\Steam\steamapps\common\Factorio` on Windows).
This breaks when Factorio is installed in a non-default Steam library folder
(a common Steam feature - users can add library folders on other drives).

Replace the hardcoded paths with actual discovery:

1. Find the Steam installation root for the current OS.
2. Parse `steamapps/libraryfolders.vdf` under that root to find which
   library folder (if any) contains Factorio (Steam AppID `427520`).
3. Derive `GameExecutablePath()` and `GameDataDir()` from the discovered
   Factorio directory.

`GameUserDir()` is unaffected (it does not depend on the Steam install
location).

## Non-goals

- Non-Steam installations (GOG, itch.io, standalone) remain covered by the
  existing `[runtime]` overrides in `config.toml` - unchanged.
- Fallback behavior is unchanged: `Runtime.ExecutablePath()` /
  `Runtime.DataDir()` still prefer config overrides first, and propagate an
  error (no silent guessing) when auto-detection fails.

## Component: `internal/platform/steam.go` (new)

```go
const factorioAppID = "427520"

var ErrFactorioNotFound = errors.New("Factorio installation not found in any Steam library")

// findFactorioDir parses steamRoot/steamapps/libraryfolders.vdf and returns
// the Factorio installation directory: <library>/steamapps/common/Factorio.
func findFactorioDir(steamRoot string) (string, error)
```

`libraryfolders.vdf` lists every Steam library folder (including the
default one under `steamRoot`) with the set of AppIDs installed in each.
Example shape:

```
"libraryfolders"
{
    "0"
    {
        "path"    "C:\\Program Files (x86)\\Steam"
        "apps"
        {
            "427520"    "123456789"
        }
    }
    "1"
    {
        "path"    "D:\\SteamLibrary"
        "apps"
        {
            "..."    "..."
        }
    }
}
```

`findFactorioDir` uses a minimal line-scanning parser rather than a general
VDF library (no VDF dependency exists in `go.mod`, and the only data needed
is the `"path"` value and whether `"427520"` appears in the following
`"apps"` block):

- Track the most recently seen `"path"` value as `currentPath`.
- When a line whose key is `"427520"` is seen, return
  `filepath.Join(currentPath, "steamapps", "common", "Factorio")`.
- If no match is found after scanning the whole file, return
  `ErrFactorioNotFound`.

This relies on Valve's actual output always emitting `"path"` before
`"apps"` within a library block, which holds for all observed
`libraryfolders.vdf` samples.

## Steam root discovery per OS

| OS | Method |
|---|---|
| Linux | Check `~/.steam/steam`, then `~/.var/app/com.valvesoftware.Steam/.steam/steam` (Flatpak), via `os.Stat`. First one that exists wins. |
| macOS | Fixed: `~/Library/Application Support/Steam`. |
| Windows | Read `HKCU:\Software\Valve\Steam` value `SteamPath` via PowerShell (see below). |
| WSL | Same registry value, fetched through Windows via PowerShell, then converted with the existing `convertWindowsToWSL()`. |

### Windows: PowerShell instead of a registry package

`internal/platform/*.go` has no build tags today - every file compiles for
every `GOOS`, and `Detect()` picks the right `Platform` at runtime. Using
`golang.org/x/sys/windows/registry` directly would require gating
`windows.go` behind `//go:build windows`, changing the package's build
model. Instead, Windows reads the registry the same way WSL already reads
Windows environment variables: by shelling out to `powershell.exe`.

`Windows` changes from a zero-field value type to a pointer type with a
memoized fetch, mirroring `WSL`:

```go
type Windows struct {
    steamPath func() (string, error)
}

func NewWindows() *Windows {
    return &Windows{steamPath: sync.OnceValues(fetchWindowsSteamPath)}
}
```

`fetchWindowsSteamPath` runs a PowerShell command reading
`(Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath).SteamPath`.
`APPDATA` / `LOCALAPPDATA` (used by `GameUserDir`, cache/config home) stay as
plain `os.Getenv` reads - they don't need the registry.

`Detect()` returns `NewWindows()` instead of `Windows{}`.

### WSL: piggyback on the existing batch fetch

`wslPowerShellScript` already fetches `ProgramFiles(x86)`, `APPDATA`, and
`LOCALAPPDATA` in a single PowerShell call, memoized via
`sync.OnceValues(fetchWindowsEnvs)`. Add `SteamPath` to the same script and
result map - no additional process spawn.

## Path construction under the discovered Factorio directory

`findFactorioDir` returns the Factorio installation directory itself. Each
OS joins a fixed, OS-specific suffix onto it:

| OS | Executable | Data dir |
|---|---|---|
| Linux | `bin/x64/factorio` | `data` |
| Windows / WSL | `bin/x64/factorio.exe` | `data` |
| macOS | `factorio.app/Contents/MacOS/factorio` | `factorio.app/Contents/data` |

The existing `steamFactorioPath` helper (which assumed the Factorio
directory sits directly under `<root>/Steam/steamapps/common/Factorio`) is
removed; call sites join directly onto `findFactorioDir`'s result since the
library folder is no longer assumed to equal the Steam root.

## Error handling

No behavior change at the `Runtime` level: `ExecutablePath()` / `DataDir()`
already prefer `Overrides` and only fall through to platform detection when
unset. Detection failures (missing Steam install, unreadable/unparseable
`libraryfolders.vdf`, Factorio AppID absent from every library) surface as
errors from `GameExecutablePath()` / `GameDataDir()`, same as today's
`ErrMissingEnv` for Windows env vars.

## Testing

- `steam.go`: table tests over hand-written `libraryfolders.vdf` fixtures -
  single library, Factorio in a non-default library, Factorio absent,
  malformed file.
- Linux / macOS: `t.TempDir()` as `$HOME`, with a real fixture file written
  under the expected `steamapps/libraryfolders.vdf` path; Linux also tests
  the native-vs-Flatpak precedence.
- Windows: inject a fake `steamPath` func (as `WSL` already allows for
  `windowsEnvs`) to avoid depending on real PowerShell/registry in tests.
- WSL: extend the existing `windowsEnvs` mock map with `SteamPath` and
  assert the converted result.
