package platform

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestResolveFactorioDirConvertsWindowsPath(t *testing.T) {
	root := t.TempDir()
	writeLibraryFolders(t, root, `"libraryfolders"
{
	"0"
	{
		"path"		"D:\\SteamLibrary"
		"apps"
		{
			"427520"		"654321000"
		}
	}
}
`)

	dir, err := resolveFactorioDir(root)
	require.NoError(t, err)
	assert.Equal(t, "/mnt/d/SteamLibrary/steamapps/common/Factorio", dir)
}
