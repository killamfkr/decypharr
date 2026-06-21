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

### Still failing with `giving up after 4 attempt(s)`?

1. **Confirm mount path** (must be `/mnt`, not `/mnt/decypharr`):
   ```bash
   docker exec decypharr cat /app/config.json | grep mount_path
   ```

2. **Check the real rclone error**:
   ```bash
   docker exec decypharr tail -50 /app/logs/rclone.log
   ```

3. **Clear a stale mount and restart**:
   ```bash
   docker exec decypharr fusermount3 -uz /mnt/decypharr 2>/dev/null || true
   docker exec decypharr fusermount3 -uz /mnt 2>/dev/null || true
   docker restart decypharr
   ```

4. Re-run the config installer from the README, remove all API key env vars, restart again.

Files appear under `/mnt/__all__/` after you add torrents via Sonarr/Radarr or the Decypharr UI.

```bash
docker exec decypharr ls -la /mnt
```

Expected: `__all__`, `__bad__`, `torrents`, `torbox`

## `transport endpoint is not connected` on restart

This happens when the container stops while rclone is still mounted. The host folder `/DATA/AppData/decypharr/mount` becomes a broken FUSE mount and Docker cannot restart.

**Fix on ZimaOS (SSH):**

```bash
# 1. Stop the container (force if needed)
docker stop decypharr 2>/dev/null || true
docker rm -f decypharr 2>/dev/null || true

# 2. Unmount the stale FUSE mount on the HOST
sudo fusermount3 -uz /DATA/AppData/decypharr/mount 2>/dev/null || true
sudo umount -l /DATA/AppData/decypharr/mount 2>/dev/null || true

# 3. Recreate the directory if it is missing or still broken
sudo mkdir -p /DATA/AppData/decypharr/mount
sudo mkdir -p /DATA/AppData/decypharr/downloads

# 4. Start decypharr again from the ZimaOS UI (or docker compose up -d)
```

If step 2 fails with "not mounted", run:

```bash
sudo ls -la /DATA/AppData/decypharr/mount
mount | grep decypharr
```

Then start the app from ZimaOS. The rclone mount is recreated inside the container on startup.

**Tip:** Stop Decypharr from the UI and wait a few seconds before editing volumes or restarting, so rclone can unmount cleanly.

## Sonarr / Radarr volumes

Add these to Sonarr and Radarr (read-only is fine):

```yaml
/DATA/AppData/decypharr/mount:/mnt:ro
/DATA/AppData/decypharr/downloads:/app/downloads:ro
```

Decypharr also needs the downloads folder:

```yaml
/DATA/AppData/decypharr/downloads:/app/downloads
```

Set `"download_folder": "/app/downloads"` in `config.json`.

