package dependency

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sakuro/factorix/internal/mod"
)

func TestEffectiveBaseRequirement(t *testing.T) {
	t.Run("explicit base entry wins over factorio_version", func(t *testing.T) {
		req := EffectiveBaseRequirement([]string{"base >= 1.2.0"}, "2.0")
		require.NotNil(t, req)
		assert.Equal(t, OpGreaterEqual, req.Operator)
		assert.Equal(t, mod.MODVersion{Major: 1, Minor: 2, Patch: 0}, req.Version)
	})

	t.Run("explicit base entry without a version yields no requirement", func(t *testing.T) {
		req := EffectiveBaseRequirement([]string{"base"}, "2.0")
		assert.Nil(t, req)
	})

	t.Run("no explicit base entry derives >= factorio_version", func(t *testing.T) {
		req := EffectiveBaseRequirement([]string{"some-mod >= 1.0.0"}, "2.0")
		require.NotNil(t, req)
		assert.Equal(t, OpGreaterEqual, req.Operator)
		assert.Equal(t, mod.MODVersion{Major: 2, Minor: 0, Patch: 0}, req.Version)
	})

	t.Run("neither source yields no requirement", func(t *testing.T) {
		assert.Nil(t, EffectiveBaseRequirement([]string{"some-mod >= 1.0.0"}, ""))
		assert.Nil(t, EffectiveBaseRequirement(nil, ""))
	})

	t.Run("unparseable factorio_version is ignored, not fatal", func(t *testing.T) {
		assert.Nil(t, EffectiveBaseRequirement(nil, "not-a-version"))
	})

	t.Run("unparseable dependency entries are skipped, not fatal", func(t *testing.T) {
		req := EffectiveBaseRequirement([]string{"!!!not-a-dep!!!", "base >= 1.1.0"}, "2.0")
		require.NotNil(t, req)
		assert.Equal(t, mod.MODVersion{Major: 1, Minor: 1, Patch: 0}, req.Version)
	})

	t.Run("a non-required base entry is ignored, falling through to factorio_version", func(t *testing.T) {
		req := EffectiveBaseRequirement([]string{"? base >= 9.9.9"}, "2.0")
		require.NotNil(t, req)
		assert.Equal(t, OpGreaterEqual, req.Operator)
		assert.Equal(t, mod.MODVersion{Major: 2, Minor: 0, Patch: 0}, req.Version)
	})
}
