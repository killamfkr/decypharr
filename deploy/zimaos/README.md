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

Add **both** of these to Sonarr and Radarr (read-only is fine):

```yaml
/DATA/AppData/decypharr/mount:/mnt:ro
/DATA/AppData/decypharr/downloads:/app/downloads:ro
```

Decypharr also needs the downloads folder:

```yaml
/DATA/AppData/decypharr/downloads:/app/downloads
```

Set `"download_folder": "/app/downloads"` in `config.json`.

## Virtual folders (Movies / Series)

Optional browse-only folders on the mount (`/mnt/Movies`, `/mnt/Series`). They do **not** replace `downloads/radarr` or `downloads/sonarr` for Radarr/Sonarr imports.

Add to `config.json` and restart Decypharr:

```json
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
}
```

Works on the current image: **Movies** hides releases with `S01E01` / `Season 1` patterns; **Series** shows them.

If you run a build with the `category` filter (this repo's PR), you can use the simpler Sonarr/Radarr mapping instead:

```json
"custom_folders": {
  "Movies": { "filters": { "category": "radarr" } },
  "Series": { "filters": { "category": "sonarr" } }
}
```

After restart, browse:

```text
/mnt/Movies/
/mnt/Series/
/mnt/__all__/    # everything still here too
```

### How imports work (important)

Decypharr does **not** copy the movie into `downloads/`. The flow is:

1. Torbox caches the file → visible under `mount/__all__/Movie.Name/`
2. Decypharr creates an empty folder → `downloads/radarr/Movie.Name/`
3. Decypharr creates **symlinks** inside that folder → `movie.mkv` → `/mnt/__all__/Movie.Name/movie.mkv`
4. Only then Radarr sees the torrent as **complete** (`pausedUP`, progress `1.0`) and imports

Radarr must mount **both** `downloads` and `mount` at the same container paths (`/app/downloads` and `/mnt`), or the symlinks cannot be followed during import.

In the Radarr download client, set **Category** to `radarr` (or `sonarr` in Sonarr).

### Folder in `downloads/radarr` but movie only in `mount` / Radarr still "downloading"

**1. Check whether symlinks exist yet** (on the ZimaOS host):

```bash
# Replace Movie.Name with your release folder name
ls -la /DATA/AppData/decypharr/downloads/radarr/
ls -la /DATA/AppData/decypharr/downloads/radarr/Movie.Name/
ls -la /DATA/AppData/decypharr/mount/__all__/Movie.Name/
```

- **Empty `downloads/radarr/Movie.Name/`** → Decypharr is still waiting to link files, or the mount scan failed. Check logs:
  ```bash
  docker logs decypharr --tail 100 2>&1 | grep -iE 'symlink|mount files|processing action|error'
  ```
- **Symlinks present** (`movie.mkv -> /mnt/__all__/...`) → Decypharr finished; fix Radarr volumes (both `mount` and `downloads` above).

**2. Confirm Radarr sees the same paths** (inside the Radarr container):

```bash
docker exec radarr ls -la /app/downloads/radarr/Movie.Name/
docker exec radarr ls -la /mnt/__all__/Movie.Name/
```

If `/app/downloads` or `/mnt` is missing inside Radarr, add the volume mounts and restart Radarr.

**3. Confirm torrent state in Decypharr** (should be `pausedUP` when done):

```bash
curl -s 'http://127.0.0.1:8282/api/v2/torrents/info' | head -c 2000
```

Look for `"state":"pausedUP"` and `"progress":1`. While still `"state":"downloading"`, Radarr will keep showing **Downloading**.

**4. Match folder names** — files must be under `mount/__all__/`, not only under `mount/torbox/`:

```bash
ls /DATA/AppData/decypharr/mount/__all__/
```

**5. Optional — nudge Radarr after symlinks exist:** Activity → Queue → manual **Import** on the item.

If symlinks never appear after ~5 minutes, paste the output of the `docker logs` grep above; common causes are a stale FUSE mount or Torbox still finishing on their side.

### Full Blu-ray disc releases (many `.m2ts` files)

Releases like `COMPLETE.UHD.BLURAY` with hundreds of `.m2ts` segments are **full disc images**, not a single movie file.

- Decypharr will symlink **every** segment (your logs show 500+ `File is ready` lines — that is normal).
- Older images use a **2 minute** verify step after symlinking; large discs often hit `timeout waiting for symlink files` and never mark the torrent complete for Radarr.
- **Radarr is not meant to import full Blu-ray disc folders** — use a **Remux** or **BluRay** `.mkv` release instead.

**Workaround on the current image** (until an updated image is available):

```json
{
  "skip_pre_cache": true
}
```

Then check for completion errors:

```bash
docker logs decypharr 2>&1 | grep -iE 'timeout waiting for symlink|Download completed|Error running post-download'
```

If you see a symlink timeout, the release is too large for the old 2-minute limit — switch to a single-file `.mkv` release.

## Plex: direct play works, mobile transcode fails

**Symptom:** Desktop/TV plays fine (direct play), phone shows `Conversion failed. The transcoder exited due to an error`.

**Cause:** Symlinks + `vfs_cache_mode: off` are fine for direct play (small reads). Mobile forces **transcoding** — Plex/ffmpeg must read much more of the file through Torbox. Without a local rclone cache, that fails.

### Fix: streaming profile (symlinks + mobile transcode)

You need **both**:

1. A decypharr image **with rclone RC size fixes** (not `cy01/blackhole:latest`)
2. `vfs_cache_mode: full` with **no manual size fields** in config
3. A large cache volume (`/DATA/AppData/decypharr/cache` → `/cache`, **30GB+ free**)

**Config** — only change `vfs_cache_mode` (do not add `vfs_cache_max_size`, `buffer_size`, etc.):

```json
"mount": {
  "type": "rclone",
  "mount_path": "/mnt",
  "rclone": {
    "cache_dir": "/cache/rclone",
    "vfs_cache_mode": "full",
    "transfers": 4
  }
}
```

See [`config.streaming.json.example`](config/config.streaming.json.example) for a full example.

**Install script:**

```bash
TORBOX_API_KEY=YOUR_KEY sh -c 'curl -fsSL https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/install-config-streaming.sh | sh'
docker restart decypharr
```

**Build a fixed image on ZimaOS** (if no prebuilt image yet):

```bash
git clone https://github.com/killamfkr/decypharr.git
cd decypharr
git checkout cursor/zimaos-torbox-rclone-edec
docker build -t decypharr:streaming .
```

In ZimaOS, change the decypharr app image to `decypharr:streaming` (or your registry tag), keep the same volumes, restart.

Verify mount succeeds:

```bash
docker logs decypharr --tail 30 | grep -i mount
ls /DATA/AppData/decypharr/mount/__all__/
```

### Plex container (symlinks + transcode)

Plex still needs the full symlink chain **and** transcode space:

```
/DATA/Media/Movies                    →  /data/movies
/DATA/AppData/decypharr/mount         →  /mnt
/DATA/AppData/decypharr/downloads     →  /app/downloads
/DATA/AppData/decypharr/plex-transcode → /transcode   (optional, recommended)
```

**Plex → Settings → Transcoder:** set **Hardware acceleration** to **Off** on ZimaOS first (HW + cloud mounts often fail).

First mobile transcode of a 4K title will be **slow** while rclone fills `/cache/rclone` — that is normal.

### Fallback: Radarr copy for mobile (works on any image)

If you cannot switch images yet:

1. Add Radarr root folder `/data/movies-mobile` → host `/DATA/Media/Movies-Mobile`
2. Create a **1080p WEB/x264** quality profile for phone-friendly releases
3. Disable **Use Hardlinks** so Radarr **copies** real files into that folder
4. Add a second Plex library **Movies (Mobile)** pointing at `/data/movies-mobile`

Copies use disk space but transcode reliably without rclone cache.

