package resolver

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"golang.org/x/sync/errgroup"

	"github.com/sakuro/factorix/internal/api"
	"github.com/sakuro/factorix/internal/dependency"
	"github.com/sakuro/factorix/internal/mod"
)

// Portal is the subset of the MOD Portal API the resolver needs. Only the
// full endpoint is usable here: /full is the only response that carries
// each release's dependencies.
type Portal interface {
	GetMODFull(ctx context.Context, name string) (*api.MODInfo, error)
}

// Resolver fetches MODs from the Portal and resolves their dependencies.
type Resolver struct {
	Portal Portal
	Logger *slog.Logger
	// InstalledBase is the installed base MOD's version, used to filter out
	// releases incompatible with the installed Factorio game version. Nil
	// skips the check (compatibility unknown).
	InstalledBase *mod.MODVersion
}

// Fetched pairs a requested MOD with its full info and selected release.
type Fetched struct {
	MOD     mod.MOD
	Info    *api.MODInfo
	Release api.Release
}

// Fetch resolves each spec to a release with up to jobs concurrent Portal
// requests. Any spec that cannot be fetched or has no matching release
// fails the whole call: these are MODs the user explicitly asked for.
func (r *Resolver) Fetch(ctx context.Context, specs []Spec, jobs int) ([]Fetched, error) {
	return concurrentFetch(ctx, jobs, specs, func(ctx context.Context, spec Spec) (Fetched, error) {
		info, err := r.Portal.GetMODFull(ctx, spec.MOD.Name)
		if err != nil {
			return Fetched{}, err
		}
		release := spec.Select(info, r.InstalledBase)
		if release == nil {
			return Fetched{}, fmt.Errorf("Release not found for %s@%s", spec.MOD.Name, spec.VersionLabel())
		}
		return Fetched{MOD: spec.MOD, Info: info, Release: *release}, nil
	})
}

// concurrentFetch runs resolve for each spec, jobs at a time, preserving
// input order in the results.
func concurrentFetch(ctx context.Context, jobs int, specs []Spec, resolve func(context.Context, Spec) (Fetched, error)) ([]Fetched, error) {
	results := make([]Fetched, len(specs))
	group, ctx := errgroup.WithContext(ctx)
	group.SetLimit(jobs)
	for i, spec := range specs {
		group.Go(func() error {
			result, err := resolve(ctx, spec)
			if err != nil {
				return err
			}
			results[i] = result
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return nil, err
	}
	return results, nil
}

// Options tunes Resolve.
type Options struct {
	Jobs              int  // concurrent Portal requests
	FollowRecommended bool // also follow recommended dependency edges
}

// Resolve fetches each spec from the Portal, adds it to graph (via
// AddUninstalledMOD), then walks required (and, per opts, recommended)
// edges breadth-first, fetching MODs not yet in the graph and extending it
// until the frontier is empty. It returns the selected release for every
// spec and every dependency it added. Explicitly requested specs fail
// hard; a transitive dependency that cannot be fetched or has no release
// satisfying its version requirement is skipped with a warning. Base and
// expansion MODs are never fetched.
func (r *Resolver) Resolve(ctx context.Context, graph *dependency.Graph, specs []Spec, opts Options) (map[mod.MOD]api.Release, error) {
	initial, err := r.Fetch(ctx, specs, opts.Jobs)
	if err != nil {
		return nil, err
	}

	releases := make(map[mod.MOD]api.Release, len(initial))
	frontier := make([]mod.MOD, 0, len(initial))
	for _, f := range initial {
		if err := graph.AddUninstalledMOD(f.MOD, f.Release.Version, f.Release.InfoJSON.Dependencies); err != nil {
			return nil, err
		}
		releases[f.MOD] = f.Release
		frontier = append(frontier, f.MOD)
	}

	if err := r.resolveDependencies(ctx, graph, releases, frontier, opts); err != nil {
		return nil, err
	}
	return releases, nil
}

// missingDependency aggregates, for one MOD absent from the graph, the
// version requirements and dependents of every edge pointing at it in the
// current wave.
type missingDependency struct {
	requirements []*dependency.VersionRequirement
	requiredBy   []mod.MOD
}

func (r *Resolver) resolveDependencies(ctx context.Context, graph *dependency.Graph, releases map[mod.MOD]api.Release, frontier []mod.MOD, opts Options) error {
	processed := map[mod.MOD]bool{}
	for len(frontier) > 0 {
		missing := map[mod.MOD]*missingDependency{}
		var order []mod.MOD
		for _, m := range frontier {
			if processed[m] {
				continue
			}
			processed[m] = true
			for _, edge := range graph.EdgesFrom(m) {
				relevant := edge.Type == dependency.TypeRequired || (opts.FollowRecommended && edge.Type == dependency.TypeRecommended)
				if !relevant {
					continue
				}
				// The base MOD and the official expansions are not on the
				// Portal; they are installed with the game, never fetched.
				if edge.To.IsBase() || edge.To.IsExpansion() {
					continue
				}
				if graph.Contains(edge.To) {
					continue
				}
				dep, ok := missing[edge.To]
				if !ok {
					dep = &missingDependency{}
					missing[edge.To] = dep
					order = append(order, edge.To)
				}
				dep.requirements = append(dep.requirements, edge.Requirement)
				dep.requiredBy = append(dep.requiredBy, m)
			}
		}
		frontier = nil
		if len(missing) == 0 {
			continue
		}

		specs := make([]Spec, len(order))
		for i, m := range order {
			specs[i] = Spec{MOD: m, Latest: true}
		}
		results, err := concurrentFetch(ctx, opts.Jobs, specs, func(ctx context.Context, spec Spec) (Fetched, error) {
			dep := missing[spec.MOD]
			names := make([]string, len(dep.requiredBy))
			for i, m := range dep.requiredBy {
				names[i] = m.Name
			}
			requiredBy := strings.Join(names, ",")

			info, err := r.Portal.GetMODFull(ctx, spec.MOD.Name)
			if err != nil {
				r.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy, "reason", err)
				return Fetched{}, nil
			}
			release := SelectCompatible(info, r.InstalledBase, dep.requirements...)
			if release == nil {
				r.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy, "reason", "no compatible release found")
				return Fetched{}, nil
			}
			return Fetched{MOD: spec.MOD, Info: info, Release: *release}, nil
		})
		if err != nil {
			return err
		}

		for _, f := range results {
			if f.Info == nil {
				continue // skipped above with a warning
			}
			if err := graph.AddUninstalledMOD(f.MOD, f.Release.Version, f.Release.InfoJSON.Dependencies); err != nil {
				return err
			}
			releases[f.MOD] = f.Release
			frontier = append(frontier, f.MOD)
		}
	}
	return nil
}
