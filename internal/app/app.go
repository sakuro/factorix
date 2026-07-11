// Package app is the composition root: it wires configuration, the
// platform runtime, logging, caches, and API clients.
package app

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/cache"
	"github.com/sakuro/factorix/internal/config"
	"github.com/sakuro/factorix/internal/httpx"
	"github.com/sakuro/factorix/internal/logging"
	"github.com/sakuro/factorix/internal/platform"
	"github.com/sakuro/factorix/internal/transfer"
)

// maskedQueryParams are query parameter names masked in HTTP logs across
// every client the app builds (credentials passed via URL query).
var maskedQueryParams = []string{"username", "token", "secure"}

// App holds the application-wide object graph. Expensive components are
// built lazily on first use, memoized via sync.OnceValues.
type App struct {
	Config  config.Config
	Runtime *platform.Runtime
	Logger  *slog.Logger

	logCloser io.Closer

	// PortalAPI returns the MOD Portal client, wired with the api cache and
	// retry as Client → CacheTransport → Retry (retry outermost, as in Ruby).
	PortalAPI func() (*api.MODPortalAPI, error)

	// Downloader returns the MOD file downloader, wired as Client → Retry
	// (no cache decorator: the downloader manages its own download-type
	// cache directly, matching Ruby's download_http_client).
	Downloader func() (*transfer.Downloader, error)

	// MODDownloadAPI returns the client for building authenticated MOD
	// download URLs. Credentials resolve lazily on first use, not here, so
	// commands that never actually download never require
	// FACTORIO_USERNAME/FACTORIO_TOKEN or player-data.json.
	MODDownloadAPI func() (*api.MODDownloadAPI, error)

	// ManagementAPI returns the client for API-key operations (upload,
	// edit, images), wired as Client → Retry with no cache. The API key
	// resolves lazily on first use, so commands only require
	// FACTORIO_API_KEY when a management operation actually runs.
	ManagementAPI func() (*api.MODManagementAPI, error)
}

// Options select the configuration and log level.
type Options struct {
	// ConfigPath is the explicitly requested configuration file (the
	// --config-path flag). When empty, FACTORIX_CONFIG is consulted, then
	// the default location (used only if present).
	ConfigPath string
	// LogLevel overrides the configured log_level when non-empty.
	LogLevel string
}

// New builds the application.
func New(opts Options) (*App, error) {
	p, err := platform.Detect()
	if err != nil {
		return nil, err
	}

	cfg, err := loadConfig(p, opts.ConfigPath)
	if err != nil {
		return nil, err
	}

	runtime := platform.NewRuntime(p, platform.Overrides{
		ExecutablePath: cfg.Runtime.ExecutablePath,
		UserDir:        cfg.Runtime.UserDir,
		DataDir:        cfg.Runtime.DataDir,
	})

	levelName := cfg.LogLevel
	if opts.LogLevel != "" {
		levelName = opts.LogLevel
	}
	level, err := logging.ParseLevel(levelName)
	if err != nil {
		return nil, err
	}
	logPath, err := runtime.FactorixLogPath()
	if err != nil {
		return nil, err
	}
	logger, closer, err := logging.NewFileLogger(logPath, level)
	if err != nil {
		return nil, err
	}

	a := &App{Config: cfg, Runtime: runtime, Logger: logger, logCloser: closer}
	a.PortalAPI = sync.OnceValues(a.buildPortalAPI)
	a.Downloader = sync.OnceValues(a.buildDownloader)
	a.MODDownloadAPI = sync.OnceValues(a.buildMODDownloadAPI)
	a.ManagementAPI = sync.OnceValues(a.buildManagementAPI)
	return a, nil
}

func loadConfig(p platform.Platform, explicitPath string) (config.Config, error) {
	path := explicitPath
	if path == "" {
		path = os.Getenv("FACTORIX_CONFIG")
	}
	if path != "" {
		return config.LoadFile(path)
	}

	// The default location is optional: absent means default configuration.
	defaultRuntime := platform.NewRuntime(p, platform.Overrides{})
	defaultPath, err := defaultRuntime.FactorixConfigPath()
	if err != nil {
		return config.Config{}, err
	}
	if _, err := os.Stat(defaultPath); err != nil {
		return config.Default(), nil
	}
	return config.LoadFile(defaultPath)
}

// Close releases resources (the log file).
func (a *App) Close() error {
	if a.logCloser != nil {
		return a.logCloser.Close()
	}
	return nil
}

func (a *App) buildPortalAPI() (*api.MODPortalAPI, error) {
	apiCache, err := a.newCache("api", a.Config.Cache.API)
	if err != nil {
		return nil, err
	}
	base := httpx.NewBaseTransport(
		time.Duration(a.Config.HTTP.ConnectTimeout)*time.Second,
		time.Duration(a.Config.HTTP.ReadTimeout)*time.Second,
	)
	transport := httpx.NewRetryTransport(
		httpx.NewCacheTransport(base, apiCache, a.Logger),
		httpx.RetryOptions{Logger: a.Logger},
	)
	client := httpx.NewClient(httpx.Options{
		Transport:    transport,
		MaskedParams: maskedQueryParams,
		Logger:       a.Logger,
	})
	portal := api.NewMODPortalAPI(client, apiCache, a.Logger)
	portal.BaseURL = modsPortalBaseURL()
	return portal, nil
}

// modsPortalBaseURL is api.DefaultPortalBaseURL, overridable via
// FACTORIX_MODS_PORTAL_URL — useful for pointing at a portal mirror, and
// for tests to run the real command tree against an httptest server rather
// than stubbing at the api package boundary.
func modsPortalBaseURL() string {
	if v := os.Getenv("FACTORIX_MODS_PORTAL_URL"); v != "" {
		return v
	}
	return api.DefaultPortalBaseURL
}

func (a *App) newCache(name string, cfg config.CacheType) (cache.Cache, error) {
	cacheDir, err := a.Runtime.FactorixCacheDir()
	if err != nil {
		return nil, err
	}
	var ttl *time.Duration
	if cfg.TTL != nil {
		d := time.Duration(*cfg.TTL) * time.Second
		ttl = &d
	}
	return cache.NewFileSystem(filepath.Join(cacheDir, name), cache.FileSystemOptions{
		TTL:                  ttl,
		MaxFileSize:          cfg.FileSystem.MaxFileSize,
		CompressionThreshold: cfg.FileSystem.CompressionThreshold,
		Logger:               a.Logger,
	})
}

func (a *App) buildDownloader() (*transfer.Downloader, error) {
	downloadCache, err := a.newCache("download", a.Config.Cache.Download)
	if err != nil {
		return nil, err
	}
	transport := httpx.NewRetryTransport(
		httpx.NewBaseTransport(
			time.Duration(a.Config.HTTP.ConnectTimeout)*time.Second,
			time.Duration(a.Config.HTTP.ReadTimeout)*time.Second,
		),
		httpx.RetryOptions{Logger: a.Logger},
	)
	client := httpx.NewClient(httpx.Options{
		Transport:    transport,
		MaskedParams: maskedQueryParams,
		Logger:       a.Logger,
	})
	return transfer.NewDownloader(downloadCache, client, a.Logger), nil
}

func (a *App) buildMODDownloadAPI() (*api.MODDownloadAPI, error) {
	playerDataPath, err := a.Runtime.PlayerDataPath()
	if err != nil {
		return nil, err
	}
	modDownload := api.NewMODDownloadAPI(func() (api.ServiceCredential, error) {
		return api.LoadServiceCredential(playerDataPath)
	})
	modDownload.BaseURL = modsPortalBaseURL()
	return modDownload, nil
}

// NamedCache pairs a configured cache with its name and TTL.
type NamedCache struct {
	Name  string
	Cache cache.Cache
	TTL   *int64 // seconds; nil = unlimited
}

// Caches returns the configured caches. The fixed order (download, api,
// info_json — the Ruby config definition order) keeps output deterministic;
// a map would randomize it per run. Instances are built fresh — cache state
// lives on disk, so they can coexist with the ones inside the API clients.
func (a *App) Caches() ([]NamedCache, error) {
	named := []struct {
		name string
		cfg  config.CacheType
	}{
		{"download", a.Config.Cache.Download},
		{"api", a.Config.Cache.API},
		{"info_json", a.Config.Cache.InfoJSON},
	}
	result := make([]NamedCache, 0, len(named))
	for _, n := range named {
		c, err := a.newCache(n.name, n.cfg)
		if err != nil {
			return nil, err
		}
		result = append(result, NamedCache{Name: n.name, Cache: c, TTL: n.cfg.TTL})
	}
	return result, nil
}

func (a *App) buildManagementAPI() (*api.MODManagementAPI, error) {
	transport := httpx.NewRetryTransport(
		httpx.NewBaseTransport(
			time.Duration(a.Config.HTTP.ConnectTimeout)*time.Second,
			time.Duration(a.Config.HTTP.ReadTimeout)*time.Second,
		),
		httpx.RetryOptions{Logger: a.Logger},
	)
	client := httpx.NewClient(httpx.Options{
		Transport:    transport,
		MaskedParams: maskedQueryParams,
		Logger:       a.Logger,
	})
	management := api.NewMODManagementAPI(client, transfer.NewUploader(client, a.Logger), api.LoadAPICredential, a.Logger)
	management.BaseURL = modsPortalBaseURL()
	// Invalidate the portal cache after any changing operation, replacing
	// Ruby's dry-events subscription.
	management.OnMODChanged = func(ctx context.Context, name string) {
		portal, err := a.PortalAPI()
		if err != nil {
			a.Logger.Warn("Skipping MOD cache invalidation", "mod", name, "error", err)
			return
		}
		if err := portal.InvalidateMODCache(ctx, name); err != nil {
			a.Logger.Warn("Failed to invalidate MOD cache", "mod", name, "error", err)
		}
	}
	return management, nil
}

// RequireGameStopped fails when Factorio is running; commands that modify
// game files call this first.
func (a *App) RequireGameStopped() error {
	running, err := a.Runtime.IsRunning()
	if err != nil {
		return err
	}
	if running {
		return fmt.Errorf("Factorio is running. Please close the game before running this command")
	}
	return nil
}
