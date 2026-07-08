package mod

// MODState is a MOD's entry in mod-list.json: the enabled flag and an
// optional version.
type MODState struct {
	Enabled bool
	Version *MODVersion // nil when the version is not specified
}
