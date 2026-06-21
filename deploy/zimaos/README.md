# Decypharr on ZimaOS (Torbox + Rclone)

Turnkey setup for ZimaOS with embedded rclone mounting. You only need to add your Torbox API key.

## Quick Start (no git clone required)

SSH into your ZimaOS device and run **one** of these:

### Option A: Install script (recommended)

```bash
TORBOX_API_KEY=your_actual_api_key curl -fsSL \
  https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/install.sh | sh
```

### Option B: Download config directly

```bash
mkdir -p /DATA/AppData/decypharr/{config,mount,cache}

curl -fsSL \
  https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/config/config.json.example \
  -o /DATA/AppData/decypharr/config/config.json
```

Then edit `/DATA/AppData/decypharr/config/config.json` and paste your Torbox API key into the `"api_key"` field.

### Option C: Create config manually

If download fails, create the file directly:

```bash
mkdir -p /DATA/AppData/decypharr/{config,mount,cache}

cat > /DATA/AppData/decypharr/config/config.json <<'EOF'
{
  "bind_address": "0.0.0.0",
  "port": "8282",
  "log_level": "info",
  "use_auth": false,
  "download_folder": "/app/downloads",
  "categories": ["sonarr", "radarr"],
  "debrids": [
    {
      "provider": "torbox",
      "name": "torbox",
      "api_key": "PASTE_YOUR_TORBOX_API_KEY_HERE"
    }
  ],
  "mount": {
    "type": "rclone",
    "mount_path": "/mnt/decypharr",
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
```

Replace `PASTE_YOUR_TORBOX_API_KEY_HERE` with your real key from the [Torbox dashboard](https://torbox.app/settings).

## Install in ZimaOS

1. Open the ZimaOS dashboard
2. Click **+** → **Install a customized app**
3. Go to the **Docker Compose** tab
4. Paste the contents of [`docker-compose.yml`](docker-compose.yml) (or download it from the repo)
5. Update the three volume `source` paths if your storage is not under `/DATA`
6. Add environment variable `TORBOX_API_KEY` with your API key (optional if already in `config.json`)
7. Click **Submit** and start the app

### Docker Compose download

```bash
curl -fsSL \
  https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/docker-compose.yml
```

Copy the output into the ZimaOS Docker Compose installer.

## Open Decypharr

Visit `http://<your-zimaos-ip>:8282`

## Connect Sonarr / Radarr

Add Decypharr as a download client:

| Setting | Value |
|---------|-------|
| Type | qBittorrent |
| Host | `<zimaos-ip>` |
| Port | `8282` |
| Category | `sonarr` or `radarr` |
| Username / Password | leave empty (auth is disabled in this preset) |

Point your *Arr root folders at the mounted path:

- Inside Decypharr container: `/mnt/decypharr/torbox/__all__/...`
- On ZimaOS host: `/DATA/AppData/decypharr/mount/decypharr/torbox/__all__/...`

If Sonarr/Radarr run in separate containers, mount the host mount folder into them:

```yaml
volumes:
  - /DATA/AppData/decypharr/mount:/mnt:ro
```

## What is pre-configured

- **Debrid**: Torbox (API key in `config.json` or `TORBOX_API_KEY` env var)
- **Mount**: Embedded rclone at `/mnt/decypharr`
- **Cache**: `/cache/rclone` on your storage drive (not eMMC)
- **FUSE**: `/dev/fuse`, `SYS_ADMIN`, and `rshared` mount propagation

## Troubleshooting

### `cp: cannot stat 'deploy/zimaos/...'`

That path only exists inside the git repo. Use the **curl** or **install script** commands above instead — they download the files directly to ZimaOS.

### Rclone mount fails

1. Confirm `/dev/fuse` is passed to the container
2. Confirm `SYS_ADMIN` capability is enabled
3. Confirm the `/mnt` volume uses `rshared` propagation
4. Check logs: `/DATA/AppData/decypharr/config/logs/rclone.log`

### Permission errors

Match `PUID`/`PGID` in `docker-compose.yml` to the user that runs your media apps (usually `1000`).

### Cache filling system drive

This preset stores rclone cache at `/DATA/AppData/decypharr/cache`. Keep that path on a large HDD/NVMe volume, not the internal eMMC.

### API key not picked up

Either set `"api_key"` in `/DATA/AppData/decypharr/config/config.json`, or set `TORBOX_API_KEY` in the container environment. Decypharr also accepts `DECYPHARR_TORBOX_API_KEY`.
