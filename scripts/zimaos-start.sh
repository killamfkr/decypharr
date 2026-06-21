#!/bin/sh
set -e

mkdir -p /app/logs /app/cache /app/downloads /app/rclone /mnt/decypharr /cache/rclone

write_config() {
    printf '%s' \
        '{"bind_address":"0.0.0.0","port":"8282","log_level":"info","use_auth":false,' \
        '"download_folder":"/app/downloads","categories":["sonarr","radarr"],' \
        '"debrids":[{"provider":"torbox","name":"torbox","api_key":"' \
        "$TORBOX_API_KEY" \
        '"}],"mount":{"type":"rclone","mount_path":"/mnt/decypharr","rclone":{' \
        '"cache_dir":"/cache/rclone","vfs_cache_mode":"writes","vfs_cache_max_size":"10GB",' \
        '"vfs_read_chunk_size":"128MB","vfs_read_ahead":"256MB","buffer_size":"16MB","transfers":4}}}' \
        > /app/config.json
}

if [ -n "$TORBOX_API_KEY" ]; then
    if [ ! -f /app/config.json ]; then
        write_config
    elif ! grep -q '"api_key"[[:space:]]*:[[:space:]]*"[^"]' /app/config.json 2>/dev/null; then
        write_config
    elif ! grep -q '"download_folder"' /app/config.json 2>/dev/null; then
        write_config
    fi
fi

exec /usr/bin/decypharr --config /app
