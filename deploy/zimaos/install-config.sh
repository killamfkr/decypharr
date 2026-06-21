#!/bin/sh
# Run on ZimaOS host (SSH) to install a working config.
# Usage: TORBOX_API_KEY=your_key sh install-config.sh

set -e

CONFIG_DIR="${CONFIG_DIR:-/DATA/AppData/decypharr/config}"
API_KEY="${TORBOX_API_KEY:?Set TORBOX_API_KEY}"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config.json" <<EOF
{
  "port": "8282",
  "log_level": "info",
  "use_auth": false,
  "download_folder": "/app/downloads",
  "categories": ["sonarr", "radarr"],
  "custom_folders": {
    "Movies": {
      "filters": {
        "not_regex": "(?i)(S\\d{1,4}E\\d{1,4}|Season[\\s._-]?\\d+)",
        "not_files_regex": "(?i)(S\\d{1,4}E\\d{1,4}|Season[\\s._-]?\\d+)"
      }
    },
    "Series": {
      "filters": {
        "regex": "(?i)(S\\d{1,4}E\\d{1,4}|Season[\\s._-]?\\d+)",
        "files_regex": "(?i)(S\\d{1,4}E\\d{1,4}|Season[\\s._-]?\\d+)"
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
      "vfs_cache_mode": "off",
      "transfers": 4
    }
  }
}
EOF

echo "Wrote $CONFIG_DIR/config.json"
echo "IMPORTANT: Remove TORBOX_API_KEY from the ZimaOS app environment, then restart decypharr."
