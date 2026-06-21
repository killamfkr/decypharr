#!/bin/sh
# Streaming / Plex mobile transcode profile for ZimaOS.
# Requires a decypharr image with rclone RC size conversion (not cy01/blackhole:latest).
#
# Usage: TORBOX_API_KEY=your_key sh install-config-streaming.sh

set -e

CONFIG_DIR="${CONFIG_DIR:-/DATA/AppData/decypharr/config}"
API_KEY="${TORBOX_API_KEY:?Set TORBOX_API_KEY}"
CACHE_DIR="${CACHE_DIR:-/DATA/AppData/decypharr/cache}"

mkdir -p "$CONFIG_DIR" "$CACHE_DIR/rclone"

cat > "$CONFIG_DIR/config.json" <<EOF
{
  "port": "8282",
  "log_level": "info",
  "use_auth": false,
  "download_folder": "/app/downloads",
  "skip_pre_cache": true,
  "categories": ["sonarr", "radarr"],
  "custom_folders": {
    "Movies": {
      "filters": {
        "not_regex": "(?i)(S\\\\d{1,4}E\\\\d{1,4}|Season[\\\\s._-]?\\\\d+)",
        "not_files_regex": "(?i)(S\\\\d{1,4}E\\\\d{1,4}|Season[\\\\s._-]?\\\\d+)"
      }
    },
    "Series": {
      "filters": {
        "regex": "(?i)(S\\\\d{1,4}E\\\\d{1,4}|Season[\\\\s._-]?\\\\d+)",
        "files_regex": "(?i)(S\\\\d{1,4}E\\\\d{1,4}|Season[\\\\s._-]?\\\\d+)"
      }
    }
  },
  "debrids": [
    {
      "provider": "torbox",
      "name": "torbox",
      "api_key": "${API_KEY}"
    }
  ],
  "mount": {
    "type": "rclone",
    "mount_path": "/mnt",
    "rclone": {
      "cache_dir": "/cache/rclone",
      "vfs_cache_mode": "full",
      "transfers": 4
    }
  }
}
EOF

echo "Wrote $CONFIG_DIR/config.json (streaming profile)"
echo "Ensure /DATA/AppData/decypharr/cache has at least 30GB free for Plex mobile transcodes."
echo "IMPORTANT: Use a decypharr image with rclone size fixes, not cy01/blackhole:latest."
echo "Remove TORBOX_API_KEY from the ZimaOS app environment, then restart decypharr."
