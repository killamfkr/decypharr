# Decypharr on ZimaOS

Copy-paste install. No SSH, no curl, no manual config files.

## Install

1. Open ZimaOS → **+** → **Install a customized app**
2. Go to the **Docker Compose** tab
3. Paste the contents of [`docker-compose.yml`](docker-compose.yml)
4. Replace `PASTE_YOUR_TORBOX_API_KEY_HERE` with your [Torbox API key](https://torbox.app/settings)
5. If your storage is not under `/DATA`, update the three volume paths in the compose file
6. Click **Submit** and start the app

Open `http://<your-zimaos-ip>:8282` when the container is running.

## What you get

- Torbox debrid
- Embedded rclone mount at `/mnt/decypharr`
- FUSE permissions pre-configured (`/dev/fuse`, `SYS_ADMIN`, `rshared`)

The compose file creates `config.json` automatically on first start. You only edit the API key in the compose file.

## Sonarr / Radarr

Add Decypharr as a **qBittorrent** download client on port `8282`.

Mount this into your *Arr containers so they can see the files:

```yaml
volumes:
  - /DATA/AppData/decypharr/mount:/mnt:ro
```

## Troubleshooting

**Container exits immediately** — you forgot to replace `PASTE_YOUR_TORBOX_API_KEY_HERE`.

**Rclone mount fails** — confirm `/dev/fuse`, `SYS_ADMIN`, and `:rshared` on the `/mnt` volume are all present in the compose file.

**Permission errors** — change `PUID`/`PGID` to match your media apps (usually `1000`).
