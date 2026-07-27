package resolver

import (
	"context"
	"fmt"
	"log/slog"

	"golang.org/x/sync/errgroup"

	"github.com/sakuro/factorix/internal/api"
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
