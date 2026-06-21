# Decypharr on ZimaOS

## Install

1. Create folders: `sudo mkdir -p /DATA/AppData/decypharr/{config,mount,cache}`
2. ZimaOS → **+** → **Install a customized app** → paste [`docker-compose.yml`](docker-compose.yml)
3. Set **`TORBOX_API_KEY`** in Environment
4. Start the app

## Where files appear

The rclone mount is at **`/mnt`** inside the container. On the host that is:

```
/DATA/AppData/decypharr/mount/
```

You should see folders like:

```
__all__/     ← completed downloads (via Sonarr/Radarr)
__bad__/     ← failed imports
torrents/    ← active torrents
torbox/      ← Torbox provider folder
```

**`__all__` is only populated after you add torrents** through Decypharr (Sonarr/Radarr qBittorrent client). An empty `__all__` with the other folders visible means the mount is working.

## Mount looks empty?

### 1. Check inside the container (not just the host folder)

```bash
docker exec decypharr ls -la /mnt
```

If folders show here but not on the host, ZimaOS stripped `rshared` propagation. Re-deploy via SSH:

```bash
cd /tmp
curl -fsSLO https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/docker-compose.yml
# set TORBOX_API_KEY, then:
sudo docker compose up -d
```

### 2. Fix broken config and restart

```bash
sudo rm -f /DATA/AppData/decypharr/config/config.json
```

Restart the container (with `TORBOX_API_KEY` set). The compose file rewrites a working config.

### 3. Check rclone logs

```bash
docker exec decypharr cat /app/logs/rclone.log | tail -30
```

### 4. Add a test torrent

In Decypharr UI, add a magnet/torrent or send one from Sonarr. Files appear under `/mnt/__all__/`.

## Sonarr / Radarr

- Download client: **qBittorrent**, port **8282**
- Mount into *Arr containers: `/DATA/AppData/decypharr/mount:/mnt:ro`
