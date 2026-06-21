#!/bin/sh
# Write a turnkey Torbox + rclone config when TORBOX_API_KEY is set.
bootstrap_torbox_config() {
    if [ -f /app/config.json ] && grep -q '"api_key"[[:space:]]*:[[:space:]]*"[^"]' /app/config.json 2>/dev/null; then
        return 0
    fi

    if [ -n "$TORBOX_API_KEY" ]; then
        echo "Creating Decypharr config for Torbox + rclone..."

        cat > /app/config.json <<EOF
{
  "port": "8282",
  "log_level": "info",
  "use_auth": false,
  "download_folder": "/app/downloads",
  "categories": ["sonarr", "radarr"],
  "debrids": [
    {
      "provider": "torbox",
      "name": "torbox",
      "api_key": "${TORBOX_API_KEY}"
    }
  ],
  "mount": {
    "type": "rclone",
    "mount_path": "/mnt",
    "rclone": {
      "cache_dir": "/cache/rclone",
      "vfs_cache_mode": "writes",
      "vfs_cache_max_size": "10GB",
      "vfs_read_chunk_size": "128MB",
      "vfs_read_ahead": "256MB",
      "buffer_size": "16MB",
      "transfers": 4
    }
  }
}
EOF
        return 0
    fi

    if [ -f /defaults/config.json ] && [ ! -f /app/config.json ]; then
        echo "Copying default Decypharr config..."
        cp /defaults/config.json /app/config.json
    fi
}
