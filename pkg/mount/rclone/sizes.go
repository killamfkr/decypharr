package rclone

import (
	"strings"

	"github.com/sirrobot01/decypharr/internal/config"
)

const (
	defaultRCBufferSize   int64 = 16 << 20  // 16MB
	defaultRCChunkSize    int64 = 128 << 20 // 128MB
	defaultRCReadAhead    int64 = 256 << 20 // 256MB
	defaultRCCacheMaxSize int64 = 20 << 30  // 20GB
)

// sizeForRC converts human-readable sizes (e.g. "16MB", "16M", "10G") to bytes for the rclone RC API.
// Rclone RC expects integer bytes for Size fields.
func sizeForRC(size string) (int64, bool) {
	size = strings.TrimSpace(size)
	if size == "" || strings.EqualFold(size, "off") {
		return 0, false
	}

	bytes, err := config.ParseSize(size)
	if err != nil {
		return 0, false
	}
	return bytes, true
}

func setRCSize(m map[string]interface{}, key, size string) {
	if bytes, ok := sizeForRC(size); ok {
		m[key] = bytes
	}
}

// setRCSizeWithDefault sets a byte size from config or uses defaultBytes when cache is enabled.
func setRCSizeWithDefault(m map[string]interface{}, key, size string, defaultBytes int64) {
	if bytes, ok := sizeForRC(size); ok {
		m[key] = bytes
		return
	}
	if defaultBytes > 0 {
		m[key] = defaultBytes
	}
}
