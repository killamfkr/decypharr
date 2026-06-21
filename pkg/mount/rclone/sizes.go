package rclone

import (
	"strings"

	"github.com/sirrobot01/decypharr/internal/config"
)

// sizeForRC converts human-readable sizes (e.g. "16MB") to bytes for the rclone RC API.
// Rclone RC expects integer bytes for Size fields; suffix strings must use M/G without B.
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
