package manager

import (
	"os"
	"testing"
	"time"

	"github.com/sirrobot01/decypharr/internal/config"
)

func TestCustomFoldersCategoryFilter(t *testing.T) {
	t.Parallel()

	cf := &CustomFolders{
		filters: map[string][]directoryFilter{
			"Movies": {
				{filterType: filterByCategory, value: "radarr"},
			},
			"Series": {
				{filterType: filterByCategory, value: "sonarr"},
			},
		},
		folders: []string{"Movies", "Series"},
	}

	info := &FileInfo{name: "Example.Release", size: 1}
	now := time.Now()

	if !cf.matchesFilter("Movies", info, now, "radarr", nil) {
		t.Fatal("expected radarr entry in Movies folder")
	}
	if cf.matchesFilter("Movies", info, now, "sonarr", nil) {
		t.Fatal("did not expect sonarr entry in Movies folder")
	}
	if !cf.matchesFilter("Series", info, now, "sonarr", nil) {
		t.Fatal("expected sonarr entry in Series folder")
	}
	if cf.matchesFilter("Series", info, now, "", nil) {
		t.Fatal("did not expect uncategorized entry in Series folder")
	}
}

func TestInitCustomFoldersCategoryFilter(t *testing.T) {
	t.Parallel()

	m := &Manager{
		config: &config.Config{
			CustomFolders: map[string]config.CustomFolders{
				"Movies": {Filters: map[string]string{"category": "radarr"}},
			},
		},
	}
	m.initCustomFolders()

	info := &FileInfo{name: "Movie.2024", size: 1}
	if !m.customFolders.matchesFilter("Movies", info, time.Now(), "radarr", func() []string { return nil }) {
		t.Fatal("expected category filter to match radarr")
	}
}

var _ os.FileInfo = (*FileInfo)(nil)
