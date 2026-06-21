# Decypharr on ZimaOS

## The rclone 400 error (`parsing "10G"`)

The `cy01/blackhole:latest` image passes size strings like `16MB` / `10GB` to rclone, which fails. It also re-adds those values when `TORBOX_API_KEY` is in the container environment.

**Fix: use a minimal config and do NOT leave `TORBOX_API_KEY` in the app environment.**

## Quick fix (SSH)

```bash
# 1. Write a minimal config (replace YOUR_KEY)
TORBOX_API_KEY=YOUR_KEY sh -c 'curl -fsSL https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/install-config.sh | sh'

# 2. In ZimaOS app settings, REMOVE these environment variables if present:
#    TORBOX_API_KEY
#    SETUP_TORBOX_API_KEY

# 3. Restart decypharr
docker restart decypharr

# 4. Verify
docker exec decypharr cat /app/config.json
docker exec decypharr ls -la /mnt
```

`config.json` must look like this (no `buffer_size`, no `vfs_cache_max_size`, `mount_path` is `/mnt`):

```json
"mount": {
  "type": "rclone",
  "mount_path": "/mnt",
  "rclone": {
    "cache_dir": "/cache/rclone",
    "vfs_cache_mode": "off",
    "transfers": 4
  }
}
```

## ZimaOS compose install

1. Paste [`docker-compose.yml`](docker-compose.yml)
2. Set **`SETUP_TORBOX_API_KEY`** only (not `TORBOX_API_KEY`) in Environment
3. Start the app, then **remove `SETUP_TORBOX_API_KEY`** from Environment and restart again

The startup script writes config once, then runs decypharr without the API key env var so sizes are not re-injected.

## After mount works

Files appear under `/mnt/__all__/` after you add torrents via Sonarr/Radarr or the Decypharr UI.

```bash
docker exec decypharr ls -la /mnt
```

Expected: `__all__`, `__bad__`, `torrents`, `torbox`
