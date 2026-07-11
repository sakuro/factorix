package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/sakuro/factorix/internal/app"
	"github.com/sakuro/factorix/internal/cache"
)

func newCacheCommand(c *cli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cache",
		Short: "Manage caches",
	}
	cmd.AddCommand(newCacheStatCommand(c), newCacheEvictCommand(c))
	return cmd
}

func newCacheStatCommand(c *cli) *cobra.Command {
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "stat",
		Short: "Display cache statistics",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			application, err := c.App()
			if err != nil {
				return err
			}
			caches, err := application.Caches()
			if err != nil {
				return err
			}

			stats := make([]namedCacheStats, 0, len(caches))
			for _, named := range caches {
				entries, err := named.Cache.Entries(cmd.Context())
				if err != nil {
					return err
				}
				stats = append(stats, namedCacheStats{
					name:  named.Name,
					stats: collectCacheStats(named.TTL, entries, named.Cache.Info()),
				})
			}

			p := c.printer(cmd)
			if jsonOutput {
				return outputCacheStatsJSON(p, stats)
			}
			outputCacheStatsText(p, stats)
			return nil
		},
	}
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output in JSON format")
	return cmd
}

// cacheStats mirrors the shape of Ruby's stat JSON; struct order fixes the
// key order.
type cacheStats struct {
	TTL     *int64          `json:"ttl"`
	Entries cacheEntryStats `json:"entries"`
	Size    cacheSizeStats  `json:"size"`
	Age     cacheAgeStats   `json:"age"`
	Backend backendInfoJSON `json:"backend_info"`
}

type namedCacheStats struct {
	name  string
	stats cacheStats
}

type cacheEntryStats struct {
	Total   int `json:"total"`
	Valid   int `json:"valid"`
	Expired int `json:"expired"`
}

type cacheSizeStats struct {
	Total int64 `json:"total"`
	Avg   int64 `json:"avg"`
	Min   int64 `json:"min"`
	Max   int64 `json:"max"`
}

// Ages are seconds; nil when the cache is empty.
type cacheAgeStats struct {
	Oldest *float64 `json:"oldest"`
	Newest *float64 `json:"newest"`
	Avg    *float64 `json:"avg"`
}

type backendInfoJSON struct {
	Type                 string `json:"type"`
	Directory            string `json:"directory"`
	MaxFileSize          *int64 `json:"max_file_size"`
	CompressionThreshold *int64 `json:"compression_threshold"`
	StaleLocks           int    `json:"stale_locks"`
}

func collectCacheStats(ttl *int64, entries []cache.Entry, info cache.BackendInfo) cacheStats {
	stats := cacheStats{
		TTL: ttl,
		Backend: backendInfoJSON{
			Type:                 info.Type,
			Directory:            info.Directory,
			MaxFileSize:          info.MaxFileSize,
			CompressionThreshold: info.CompressionThreshold,
			StaleLocks:           info.StaleLocks,
		},
	}

	stats.Entries.Total = len(entries)
	for _, e := range entries {
		if !e.Expired {
			stats.Entries.Valid++
		}
	}
	stats.Entries.Expired = stats.Entries.Total - stats.Entries.Valid

	if len(entries) == 0 {
		return stats
	}

	var totalAge time.Duration
	stats.Size.Min = entries[0].Size
	oldest, newest := entries[0].Age, entries[0].Age
	for _, e := range entries {
		stats.Size.Total += e.Size
		stats.Size.Min = min(stats.Size.Min, e.Size)
		stats.Size.Max = max(stats.Size.Max, e.Size)
		totalAge += e.Age
		oldest = max(oldest, e.Age)
		newest = min(newest, e.Age)
	}
	stats.Size.Avg = stats.Size.Total / int64(len(entries))

	oldestSec, newestSec := oldest.Seconds(), newest.Seconds()
	avgSec := (totalAge / time.Duration(len(entries))).Seconds()
	stats.Age = cacheAgeStats{Oldest: &oldestSec, Newest: &newestSec, Avg: &avgSec}
	return stats
}

// outputCacheStatsJSON renders the stats as one JSON object whose keys keep
// the canonical cache order (assembled by hand — a map would sort them).
func outputCacheStatsJSON(p *printer, stats []namedCacheStats) error {
	var compact bytes.Buffer
	compact.WriteString("{")
	for i, s := range stats {
		if i > 0 {
			compact.WriteString(",")
		}
		if err := appendJSON(&compact, s.name); err != nil {
			return err
		}
		compact.WriteString(":")
		if err := appendJSON(&compact, s.stats); err != nil {
			return err
		}
	}
	compact.WriteString("}")

	var pretty bytes.Buffer
	if err := json.Indent(&pretty, compact.Bytes(), "", "  "); err != nil {
		return err
	}
	p.Println(pretty.String())
	return nil
}

func outputCacheStatsText(p *printer, stats []namedCacheStats) {
	for i, s := range stats {
		if i > 0 {
			p.Println()
		}
		p.Println(s.name + ":")
		outputSingleCacheStats(p, s.stats)
	}
}

func outputSingleCacheStats(p *printer, s cacheStats) {
	ttl := "unlimited"
	if s.TTL != nil {
		ttl = formatDuration(*s.TTL)
	}
	p.Println("  TTL:            " + ttl)

	validPct := 0.0
	if s.Entries.Total > 0 {
		validPct = float64(s.Entries.Valid) / float64(s.Entries.Total) * 100
	}
	p.Printf("  Entries:        %d / %d (%.1f%% valid)\n", s.Entries.Valid, s.Entries.Total, validPct)

	p.Printf("  Size:           %s (avg %s)\n", formatSize(s.Size.Total), formatSize(s.Size.Avg))

	if s.Age.Oldest != nil {
		p.Printf("  Age:            %s - %s (avg %s)\n",
			formatDuration(int64(*s.Age.Newest)), formatDuration(int64(*s.Age.Oldest)), formatDuration(int64(*s.Age.Avg)))
	} else {
		p.Println("  Age:            -")
	}

	p.Println("  Backend:")
	backendLine := func(label, value string) {
		p.Printf("    %-20s %s\n", label+":", value)
	}
	backendLine("Type", s.Backend.Type)
	backendLine("Directory", s.Backend.Directory)
	backendLine("Max file size", formatSizeLimit(s.Backend.MaxFileSize))
	backendLine("Compression threshold", formatSizeLimit(s.Backend.CompressionThreshold))
	backendLine("Stale locks", strconv.Itoa(s.Backend.StaleLocks))
}

var agePattern = regexp.MustCompile(`\A(\d+)([smhd])\z`)

var ageUnits = map[string]time.Duration{
	"s": time.Second,
	"m": time.Minute,
	"h": time.Hour,
	"d": 24 * time.Hour,
}

// parseAge parses an age like "30s", "5m", "2h", or "7d".
func parseAge(age string) (time.Duration, error) {
	m := agePattern.FindStringSubmatch(age)
	if m == nil {
		return 0, fmt.Errorf("Invalid age format: %s. Use format like 30s, 5m, 2h, 7d", age)
	}
	value, err := strconv.ParseInt(m[1], 10, 64)
	if err != nil {
		return 0, err
	}
	return time.Duration(value) * ageUnits[m[2]], nil
}

func newCacheEvictCommand(c *cli) *cobra.Command {
	var all, expired bool
	var olderThan string

	cmd := &cobra.Command{
		Use:   "evict [cache-name]...",
		Short: "Evict cache entries",
		Args:  cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			optionCount := 0
			for _, set := range []bool{all, expired, olderThan != ""} {
				if set {
					optionCount++
				}
			}
			if optionCount == 0 {
				return fmt.Errorf("One of --all, --expired, or --older-than must be specified")
			}
			if optionCount > 1 {
				return fmt.Errorf("Only one of --all, --expired, or --older-than can be specified")
			}

			var olderThanAge time.Duration
			if olderThan != "" {
				var err error
				olderThanAge, err = parseAge(olderThan)
				if err != nil {
					return err
				}
			}

			application, err := c.App()
			if err != nil {
				return err
			}
			caches, err := application.Caches()
			if err != nil {
				return err
			}
			targets, err := resolveEvictTargets(caches, args)
			if err != nil {
				return err
			}

			shouldEvict := func(e cache.Entry) bool {
				switch {
				case all:
					return true
				case expired:
					return e.Expired
				default:
					return e.Age > olderThanAge
				}
			}

			p := c.printer(cmd)
			nameWidth := 0
			for _, named := range targets {
				nameWidth = max(nameWidth, len(named.Name))
			}
			for _, named := range targets {
				count, size, err := evictCacheEntries(cmd, named.Cache, shouldEvict)
				if err != nil {
					return err
				}
				p.Info(fmt.Sprintf("%-*s: %3d entries removed (%s)", nameWidth, named.Name, count, formatSize(size)))
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&all, "all", false, "Remove all entries")
	cmd.Flags().BoolVar(&expired, "expired", false, "Remove expired entries only")
	cmd.Flags().StringVar(&olderThan, "older-than", "", "Remove entries older than AGE (e.g., 30s, 5m, 2h, 7d)")
	return cmd
}

// resolveEvictTargets maps cache-name arguments to caches; no arguments
// means every cache.
func resolveEvictTargets(caches []app.NamedCache, names []string) ([]app.NamedCache, error) {
	if len(names) == 0 {
		return caches, nil
	}
	var targets []app.NamedCache
	for _, name := range names {
		i := slices.IndexFunc(caches, func(n app.NamedCache) bool { return n.Name == name })
		if i < 0 {
			valid := make([]string, len(caches))
			for j, n := range caches {
				valid[j] = n.Name
			}
			return nil, fmt.Errorf("Unknown cache: %s. Valid caches: %s", name, strings.Join(valid, ", "))
		}
		targets = append(targets, caches[i])
	}
	return targets, nil
}

func evictCacheEntries(cmd *cobra.Command, target cache.Cache, shouldEvict func(cache.Entry) bool) (count int, size int64, err error) {
	entries, err := target.Entries(cmd.Context())
	if err != nil {
		return 0, 0, err
	}
	for _, e := range entries {
		if !shouldEvict(e) {
			continue
		}
		deleted, err := target.Delete(cmd.Context(), e.Key)
		if err != nil {
			return count, size, err
		}
		if deleted {
			count++
			size += e.Size
		}
	}
	return count, size, nil
}
