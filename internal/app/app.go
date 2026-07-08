// Package app is the composition root: it wires configuration, the
// platform runtime, logging, caches, and API clients.
package app

import (
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
)

// App holds the application-wide object graph. Expensive components are
// built lazily on first use.
type App struct {
	Config  config.Config
	Runtime *platform.Runtime
	Logger  *slog.Logger

	logCloser io.Closer

	portalOnce sync.Once
	portal     *api.MODPortalAPI
	portalErr  error
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

	return &App{Config: cfg, Runtime: runtime, Logger: logger, logCloser: closer}, nil
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

// PortalAPI returns the MOD Portal client, wired with the api cache and
// retry as Client → CacheTransport → Retry (retry outermost, as in Ruby).
func (a *App) PortalAPI() (*api.MODPortalAPI, error) {
	a.portalOnce.Do(func() {
		apiCache, err := a.newCache("api", a.Config.Cache.API)
		if err != nil {
			a.portalErr = err
			return
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
			MaskedParams: []string{"username", "token", "secure"},
			Logger:       a.Logger,
		})
		a.portal = api.NewMODPortalAPI(client, apiCache, a.Logger)
	})
	return a.portal, a.portalErr
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
