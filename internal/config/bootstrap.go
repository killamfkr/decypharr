package config

import (
	"os"
	"path/filepath"
)

const (
	defaultTorboxProvider = "torbox"
	defaultMountPath      = "/mnt"
	defaultCacheDir       = "/cache/rclone"
	defaultDownloadFolder = "/app/downloads"
)

func torboxAPIKeyFromEnv() string {
	if key := os.Getenv("TORBOX_API_KEY"); key != "" {
		return key
	}
	return getEnv("TORBOX_API_KEY")
}

// bootstrapTorboxRclone applies a turnkey Torbox + rclone configuration when an
// API key is supplied via environment variable and the config is incomplete.
func (c *Config) bootstrapTorboxRclone(apiKey string) {
	if apiKey == "" {
		return
	}

	if c.BindAddress == "" {
		c.BindAddress = "0.0.0.0"
	}

	if c.DownloadFolder == "" {
		c.DownloadFolder = defaultDownloadFolder
	}

	if len(c.Categories) == 0 {
		c.Categories = []string{"sonarr", "radarr"}
	}

	if c.Mount.Type == "" || c.Mount.Type == MountTypeNone {
		c.Mount.Type = MountTypeRclone
	}

	if c.Mount.MountPath == "" {
		c.Mount.MountPath = defaultMountPath
	}

	if c.Mount.Rclone.CacheDir == "" {
		c.Mount.Rclone.CacheDir = defaultCacheDir
	}

	if c.Mount.Rclone.VfsCacheMode == "" {
		c.Mount.Rclone.VfsCacheMode = "writes"
	}

	if c.Mount.Rclone.VfsReadChunkSize == "" {
		c.Mount.Rclone.VfsReadChunkSize = "128MB"
	}

	if c.Mount.Rclone.VfsReadAhead == "" {
		c.Mount.Rclone.VfsReadAhead = "256MB"
	}

	if c.Mount.Rclone.BufferSize == "" {
		c.Mount.Rclone.BufferSize = "16MB"
	}

	if len(c.Debrids) == 0 {
		c.Debrids = []Debrid{{
			Provider: defaultTorboxProvider,
			Name:     defaultTorboxProvider,
			APIKey:   apiKey,
		}}
		return
	}

	for i := range c.Debrids {
		provider := c.Debrids[i].Provider
		if provider == "" {
			provider = c.Debrids[i].Name
		}
		if provider == "" {
			provider = defaultTorboxProvider
		}

		if provider == defaultTorboxProvider && c.Debrids[i].APIKey == "" {
			c.Debrids[i].Provider = defaultTorboxProvider
			if c.Debrids[i].Name == "" {
				c.Debrids[i].Name = defaultTorboxProvider
			}
			c.Debrids[i].APIKey = apiKey
		}
	}
}

func (c *Config) ensureBootstrapDirectories() {
	dirs := []string{
		c.DownloadFolder,
		c.Mount.MountPath,
		c.Mount.Rclone.CacheDir,
		filepath.Join(GetMainPath(), "logs"),
		filepath.Join(GetMainPath(), "cache"),
		filepath.Join(GetMainPath(), "downloads"),
		filepath.Join(GetMainPath(), "rclone"),
	}

	for _, dir := range dirs {
		if dir == "" {
			continue
		}
		_ = os.MkdirAll(dir, 0755)
	}
}
