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
        '"cache_dir":"/cache/rclone","vfs_cache_mode":"off","transfers":4}}}' \
        > /app/config.json
}

if [ -n "$TORBOX_API_KEY" ]; then
    write_config
fi

exec /usr/bin/decypharr --config /app
