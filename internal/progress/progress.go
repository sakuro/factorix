// Package progress defines the listener interface for transfer and scan
// progress. Terminal presentation (mpb bars) arrives with the CLI commands.
package progress

// Listener receives progress events. Implementations must tolerate
// OnStart being called again after OnFinish: a retried transfer restarts
// its progress.
type Listener interface {
	// OnStart reports the total size in bytes; -1 when unknown.
	OnStart(total int64)
	// OnProgress reports the bytes transferred so far.
	OnProgress(current int64)
	// OnFinish reports completion.
	OnFinish()
}

// Start calls OnStart when the listener is non-nil.
func Start(l Listener, total int64) {
	if l != nil {
		l.OnStart(total)
	}
}

// Update calls OnProgress when the listener is non-nil.
func Update(l Listener, current int64) {
	if l != nil {
		l.OnProgress(current)
	}
}

// Finish calls OnFinish when the listener is non-nil.
func Finish(l Listener) {
	if l != nil {
		l.OnFinish()
	}
}
