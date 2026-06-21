#!/bin/sh
set -e

mkdir -p /app/logs /app/cache /app/downloads /app/rclone /mnt /cache/rclone

if [ -n "$TORBOX_API_KEY" ]; then
    printf '%s' \
        '{"port":"8282","log_level":"info","use_auth":false,' \
        '"download_folder":"/app/downloads","categories":["sonarr","radarr"],' \
        '"debrids":[{"provider":"torbox","name":"torbox","api_key":"' \
        "$TORBOX_API_KEY" \
        '"}],"mount":{"type":"rclone","mount_path":"/mnt","rclone":{' \
        '"cache_dir":"/cache/rclone","vfs_cache_mode":"off","transfers":4}}}' \
        > /app/config.json
fi

# Do not pass TORBOX_API_KEY to decypharr — the current image re-adds broken rclone size defaults from it.
exec env -u TORBOX_API_KEY /usr/bin/decypharr --config /app
