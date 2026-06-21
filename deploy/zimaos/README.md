# Decypharr on ZimaOS

## Install

1. ZimaOS → **+** → **Install a customized app** → **Docker Compose**
2. Paste [`docker-compose.yml`](docker-compose.yml)
3. In the **Environment** section, set `TORBOX_API_KEY` to your [Torbox API key](https://torbox.app/settings)
4. Create the three host folders if ZimaOS does not create them automatically:
   - `/DATA/AppData/decypharr/config`
   - `/DATA/AppData/decypharr/mount`
   - `/DATA/AppData/decypharr/cache`
5. Submit and start the app

Open `http://<your-zimaos-ip>:8282`

## If the app fails to start

### 1. Set TORBOX_API_KEY in the ZimaOS UI

Do not leave `TORBOX_API_KEY` empty. Set it in the app's **Environment** settings after install, not only in the YAML.

### 2. Create the host folders first

```bash
sudo mkdir -p /DATA/AppData/decypharr/config
sudo mkdir -p /DATA/AppData/decypharr/mount
sudo mkdir -p /DATA/AppData/decypharr/cache
```

### 3. Check container logs

In ZimaOS, open the app → **Logs** (or run `docker logs decypharr` via SSH).

### 4. Try the fallback compose (no rshared)

If the standard compose still fails, use [`docker-compose.fallback.yml`](docker-compose.fallback.yml). It uses simpler volume syntax that the ZimaOS UI handles more reliably.

### 5. Use SSH + docker compose (most reliable)

```bash
sudo mkdir -p /DATA/AppData/decypharr/{config,mount,cache}
cd /tmp
curl -fsSLO https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/docker-compose.yml
# Edit TORBOX_API_KEY in the file, then:
sudo docker compose up -d
```

## Sonarr / Radarr

Add Decypharr as **qBittorrent** on port `8282`. Mount into *Arr containers:

```yaml
volumes:
  - /DATA/AppData/decypharr/mount:/mnt:ro
```
