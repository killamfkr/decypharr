# Decypharr on ZimaOS

## Install

1. Create folders on ZimaOS (SSH):
   ```bash
   sudo mkdir -p /DATA/AppData/decypharr/{config,mount,cache}
   ```
2. ZimaOS → **+** → **Install a customized app** → **Docker Compose**
3. Paste [`docker-compose.yml`](docker-compose.yml)
4. Set **`TORBOX_API_KEY`** in the app's **Environment** settings to your [Torbox API key](https://torbox.app/settings)
5. Start the app

Open `http://<your-zimaos-ip>:8282` — you should go straight to the dashboard, not the setup wizard.

## Already installed and stuck on setup wizard?

Your old install created an empty `config.json`. Fix it:

1. Set `TORBOX_API_KEY` in the ZimaOS app environment (if not already)
2. Delete the old config and restart:
   ```bash
   sudo rm -f /DATA/AppData/decypharr/config/config.json
   ```
3. Restart the Decypharr container in ZimaOS

The compose file auto-writes a complete config on start when `TORBOX_API_KEY` is set.

## If the app fails to start

Try [`docker-compose.fallback.yml`](docker-compose.fallback.yml) (simpler volumes).

## Sonarr / Radarr

Add Decypharr as **qBittorrent** on port `8282`. Mount into *Arr containers:

```yaml
volumes:
  - /DATA/AppData/decypharr/mount:/mnt:ro
```
