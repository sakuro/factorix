package cli

import "fmt"

// formatSize renders a byte count with binary (IEC) prefixes, matching
// Ruby's Formatting#format_size.
func formatSize(size int64) string {
	if size < 1024 {
		return fmt.Sprintf("%d B", size)
	}
	units := []string{"B", "KiB", "MiB", "GiB", "TiB"}
	value := float64(size)
	unitIndex := 0
	for value >= 1024 && unitIndex < len(units)-1 {
		value /= 1024
		unitIndex++
	}
	return fmt.Sprintf("%.1f %s", value, units[unitIndex])
}

// formatSizeLimit renders an optional size limit; nil means unlimited.
func formatSizeLimit(size *int64) string {
	if size == nil {
		return "unlimited"
	}
	return formatSize(*size)
}

// formatDuration renders whole seconds in the largest suitable units,
// matching Ruby's Formatting#format_duration.
func formatDuration(seconds int64) string {
	if seconds < 60 {
		return fmt.Sprintf("%ds", seconds)
	}
	minutes := seconds / 60
	if minutes < 60 {
		return fmt.Sprintf("%dm", minutes)
	}
	hours := minutes / 60
	if hours < 24 {
		return fmt.Sprintf("%dh %dm", hours, minutes%60)
	}
	return fmt.Sprintf("%dd %dh", hours/24, hours%24)
}
