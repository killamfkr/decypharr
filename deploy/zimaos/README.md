# Decypharr on ZimaOS (Torbox + Rclone)

Turnkey setup for ZimaOS with embedded rclone mounting. You only need to add your Torbox API key.

## Quick Start

### 1. Create folders on ZimaOS

SSH into your ZimaOS device and run:

```bash
mkdir -p /DATA/AppData/decypharr/config
mkdir -p /DATA/AppData/decypharr/mount
mkdir -p /DATA/AppData/decypharr/cache
```

If your storage is not under `/DATA`, replace paths with your actual storage location (for example `/media/Storage/AppData/decypharr/...`).

### 2. Copy the pre-made config

```bash
cp config/config.json /DATA/AppData/decypharr/config/config.json
```

### 3. Set your Torbox API key

Create a `.env` file next to `docker-compose.yml`:

```bash
cp .env.example .env
```

Edit `.env` and set your key:

```env
TORBOX_API_KEY=your_actual_api_key
```

Get your API key from the [Torbox dashboard](https://torbox.app/settings).

### 4. Install in ZimaOS

1. Open the ZimaOS dashboard
2. Click **+** → **Install a customized app**
3. Go to the **Docker Compose** tab
4. Paste the contents of `docker-compose.yml`
5. Update the three volume `source` paths if your storage is not under `/DATA`
6. Add the `TORBOX_API_KEY` environment variable (or use Compose Toolbox with the `.env` file)
7. Click **Submit** and start the app

### 5. Open Decypharr

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

- **Debrid**: Torbox (API key from `TORBOX_API_KEY`)
- **Mount**: Embedded rclone at `/mnt/decypharr`
- **Cache**: `/cache/rclone` on your storage drive (not eMMC)
- **FUSE**: `/dev/fuse`, `SYS_ADMIN`, and `rshared` mount propagation

## Troubleshooting

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

Set `TORBOX_API_KEY` in the container environment. Decypharr also accepts `DECYPHARR_TORBOX_API_KEY`.
