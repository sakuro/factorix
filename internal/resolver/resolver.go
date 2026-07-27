package resolver

import (
	"context"
	"fmt"
	"log/slog"

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
		release := spec.Select(info)
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

// missingDependency is a dependency edge pointing at a MOD not yet in the
// graph, remembered with its requirement and dependent for fetching.
type missingDependency struct {
	mod         mod.MOD
	requirement *dependency.VersionRequirement
	requiredBy  mod.MOD
}

func (r *Resolver) resolveDependencies(ctx context.Context, graph *dependency.Graph, releases map[mod.MOD]api.Release, frontier []mod.MOD, opts Options) error {
	processed := map[mod.MOD]bool{}
	for len(frontier) > 0 {
		var missing []missingDependency
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
				missing = append(missing, missingDependency{mod: edge.To, requirement: edge.Requirement, requiredBy: m})
			}
		}
		frontier = nil
		if len(missing) == 0 {
			continue
		}

		specs := make([]Spec, len(missing))
		for i, dep := range missing {
			specs[i] = Spec{MOD: dep.mod, Latest: true}
		}
		results, err := concurrentFetch(ctx, opts.Jobs, specs, func(ctx context.Context, spec Spec) (Fetched, error) {
			var requirement *dependency.VersionRequirement
			var requiredBy mod.MOD
			for _, dep := range missing {
				if dep.mod == spec.MOD {
					requirement = dep.requirement
					requiredBy = dep.requiredBy
					break
				}
			}
			info, err := r.Portal.GetMODFull(ctx, spec.MOD.Name)
			if err != nil {
				r.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy.Name, "reason", err)
				return Fetched{}, nil
			}
			release := SelectCompatible(info, requirement)
			if release == nil {
				r.Logger.Warn("Skipping dependency", "mod", spec.MOD.Name, "required_by", requiredBy.Name, "reason", "no compatible release found")
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
