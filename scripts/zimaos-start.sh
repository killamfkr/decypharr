#!/bin/sh
set -e

mkdir -p /app/logs /app/cache /app/downloads /app/rclone /mnt /cache/rclone

write_config() {
    printf '%s' \
        '{"port":"8282","log_level":"info","use_auth":false,' \
        '"download_folder":"/app/downloads","categories":["sonarr","radarr"],' \
        '"debrids":[{"provider":"torbox","name":"torbox","api_key":"' \
        "$TORBOX_API_KEY" \
        '"}],"mount":{"type":"rclone","mount_path":"/mnt","rclone":{' \
        '"cache_dir":"/cache/rclone","vfs_cache_mode":"writes","transfers":4}}}' \
        > /app/config.json
}

fix_config() {
    if [ ! -f /app/config.json ]; then
        return 0
    fi
    sed -i 's/"bind_address"[[:space:]]*:[[:space:]]*"0\.0\.0\.0"/"bind_address": ""/g' /app/config.json 2>/dev/null || true
    sed -i 's|"mount_path"[[:space:]]*:[[:space:]]*"/mnt/decypharr"|"mount_path": "/mnt"|g' /app/config.json 2>/dev/null || true
}

if [ -n "$TORBOX_API_KEY" ]; then
    if [ ! -f /app/config.json ]; then
        write_config
    elif ! grep -q '"api_key"[[:space:]]*:[[:space:]]*"[^"]' /app/config.json 2>/dev/null; then
        write_config
    elif ! grep -q '"download_folder"' /app/config.json 2>/dev/null; then
        write_config
    else
        fix_config
    fi
fi

exec /usr/bin/decypharr --config /app
