#!/usr/bin/env bash
# Decypharr + Rclone quick installer for TorBox (Ubuntu / CasaOS)
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | bash
#   curl -fsSL ... | TORBOX_API_KEY="your-key" bash
#   curl -fsSL ... | bash -s -- --yes
set -euo pipefail

VERSION="1.1.0"
NON_INTERACTIVE=false
INSTALL_METHOD="${INSTALL_METHOD:-docker}"
IMAGE="${DECYPHARR_IMAGE:-cy01/blackhole:latest}"
APP_ID="${APP_ID:-decypharr}"
CASAOS_MODE="${CASAOS_MODE:-auto}"
IS_CASAOS=false
INSTALL_DIR=""
MOUNT_DIR=""
DOWNLOADS_DIR=""
PUID="${PUID:-$(id -u)}"
PGID="${PGID:-$(id -g)}"
TZ_VALUE="${TZ:-$(cat /etc/timezone 2>/dev/null || echo UTC)}"

log() { printf '\033[0;36m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*"; }
err() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Decypharr + Rclone installer for TorBox v${VERSION}
Ubuntu and CasaOS supported.

One-liner:
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | bash

CasaOS one-liner (auto-detected on /DATA systems):
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | TORBOX_API_KEY="your-key" bash

With your TorBox API key:
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | TORBOX_API_KEY="your-key" bash

Unattended:
  curl -fsSL ... | TORBOX_API_KEY="your-key" bash -s -- --yes

Environment variables:
  TORBOX_API_KEY       TorBox API key from https://torbox.app/settings
  CASAOS_MODE          auto (default), on, or off
  INSTALL_DIR          Install directory (auto on CasaOS: /DATA/AppData/decypharr)
  MOUNT_DIR            Host mount path for rclone
  DOWNLOADS_DIR        Symlink/download folder on the host
  DECYPHARR_IMAGE      Docker image (default: cy01/blackhole:latest)
  INSTALL_METHOD       docker (default) or binary
  PUID / PGID          File ownership (default: current user, usually 1000 on CasaOS)

Options:
  -y, --yes            Non-interactive mode
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) NON_INTERACTIVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    exit 1
  }
}

run_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "Root privileges required for: $*"
    exit 1
  fi
}

detect_casaos() {
  case "$CASAOS_MODE" in
    on|true|1|yes)
      IS_CASAOS=true
      return 0
      ;;
    off|false|0|no)
      IS_CASAOS=false
      return 0
      ;;
  esac

  if [[ -d /DATA ]] && { [[ -x /usr/bin/casaos ]] || [[ -d /var/lib/casaos ]] || systemctl is-active casaos >/dev/null 2>&1; }; then
    IS_CASAOS=true
    return 0
  fi

  IS_CASAOS=false
}

configure_paths() {
  if [[ "$IS_CASAOS" == true ]]; then
    INSTALL_DIR="${INSTALL_DIR:-/DATA/AppData/${APP_ID}}"
    MOUNT_DIR="${MOUNT_DIR:-${INSTALL_DIR}/mount}"
    DOWNLOADS_DIR="${DOWNLOADS_DIR:-/DATA/Downloads/${APP_ID}}"
    PUID="${PUID:-1000}"
    PGID="${PGID:-1000}"
    log "CasaOS detected. Using ${INSTALL_DIR}"
  else
    INSTALL_DIR="${INSTALL_DIR:-${HOME}/decypharr-torbox}"
    MOUNT_DIR="${MOUNT_DIR:-${INSTALL_DIR}/mount}"
    DOWNLOADS_DIR="${DOWNLOADS_DIR:-${INSTALL_DIR}/downloads}"
  fi
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
  else
    err "Docker Compose is required. Install Docker Compose v2."
    exit 1
  fi
}

ensure_docker() {
  need_cmd docker
  detect_compose
  DOCKER_PREFIX=()

  if ! docker info >/dev/null 2>&1; then
    if command -v systemctl >/dev/null 2>&1; then
      run_root systemctl start docker 2>/dev/null || true
      run_root systemctl enable docker 2>/dev/null || true
    fi
  fi

  if ! docker info >/dev/null 2>&1; then
    if sudo docker info >/dev/null 2>&1; then
      DOCKER_PREFIX=(sudo)
      COMPOSE=("${DOCKER_PREFIX[@]}" "${COMPOSE[@]}")
    else
      err "Docker is installed but not running. Start Docker and retry."
      exit 1
    fi
  fi
}

install_host_deps() {
  if [[ -e /dev/fuse ]]; then
    log "FUSE device found."
  else
    warn "/dev/fuse not found. Rclone mounts may not work until FUSE is installed."
  fi

  if command -v apt-get >/dev/null 2>&1; then
    local missing=()
    dpkg -s fuse3 >/dev/null 2>&1 || missing+=(fuse3)
    dpkg -s libfuse2 >/dev/null 2>&1 || missing+=(libfuse2)
    if ((${#missing[@]} > 0)); then
      log "Installing Ubuntu packages: ${missing[*]} libfuse2 curl ca-certificates"
      run_root apt-get update -qq
      run_root apt-get install -y "${missing[@]}" libfuse2 curl ca-certificates
    fi
  elif command -v apk >/dev/null 2>&1; then
    run_root apk add --no-cache fuse3 curl ca-certificates 2>/dev/null || true
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y fuse fuse3 curl ca-certificates 2>/dev/null || true
  fi
}

prompt_torbox_key() {
  if [[ -n "${TORBOX_API_KEY:-}" ]]; then
    return 0
  fi

  if [[ "$NON_INTERACTIVE" == true ]]; then
    warn "No TORBOX_API_KEY provided. Decypharr will start with the setup wizard."
    return 0
  fi

  echo
  echo "Get your TorBox API key from: https://torbox.app/settings"
  read -rsp "TorBox API key (leave blank to configure later in the web UI): " TORBOX_API_KEY
  echo
}

verify_torbox_key() {
  [[ -z "${TORBOX_API_KEY:-}" ]] && return 0
  need_cmd curl

  local status
  status=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer ${TORBOX_API_KEY}" \
    "https://api.torbox.app/v1/api/user/me" || true)

  case "$status" in
    200) log "TorBox API key verified." ;;
    401|403)
      err "TorBox rejected this API key (HTTP ${status})."
      exit 1
      ;;
    000|"") warn "Could not reach TorBox API. Continuing anyway." ;;
    *) warn "Unexpected TorBox API response (HTTP ${status}). Continuing anyway." ;;
  esac
}

prepare_directories() {
  mkdir -p \
    "${INSTALL_DIR}/config/cache/rclone" \
    "${MOUNT_DIR}" \
    "${DOWNLOADS_DIR}"

  run_root chown -R "${PUID}:${PGID}" "${INSTALL_DIR}" "${DOWNLOADS_DIR}" 2>/dev/null || true
}

setup_mount_propagation() {
  if findmnt -n "$MOUNT_DIR" >/dev/null 2>&1; then
    log "Mount propagation already configured at ${MOUNT_DIR}"
    return 0
  fi

  log "Configuring FUSE mount propagation at ${MOUNT_DIR}..."
  run_root mount --bind "$MOUNT_DIR" "$MOUNT_DIR"
  run_root mount --make-shared "$MOUNT_DIR"
}

install_mount_systemd() {
  local service_file="/etc/systemd/system/decypharr-mount.service"
  local escaped_mount
  escaped_mount=$(printf '%s' "$MOUNT_DIR" | sed 's/[\\&|]/\\&/g')

  run_root tee "$service_file" >/dev/null <<EOF
[Unit]
Description=Decypharr mount propagation for rclone
After=local-fs.target
Before=docker.service casaos.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'mkdir -p ${escaped_mount} && (findmnt -n ${escaped_mount} >/dev/null 2>&1 || (mount --bind ${escaped_mount} ${escaped_mount} && mount --make-shared ${escaped_mount}))'

[Install]
WantedBy=multi-user.target
EOF

  run_root systemctl daemon-reload
  run_root systemctl enable decypharr-mount.service >/dev/null 2>&1 || true
  run_root systemctl start decypharr-mount.service >/dev/null 2>&1 || true
  log "Installed systemd unit decypharr-mount.service for reboot persistence."
}

write_casaos_compose() {
  cat >"${INSTALL_DIR}/docker-compose.yml" <<EOF
name: ${APP_ID}
services:
  decypharr:
    image: ${IMAGE}
    container_name: decypharr
    restart: unless-stopped
    network_mode: bridge
    environment:
      PUID: \$PUID
      PGID: \$PGID
      TZ: \$TZ
    ports:
      - target: 8282
        published: "8282"
        protocol: tcp
    volumes:
      - type: bind
        source: ${INSTALL_DIR}/config
        target: /app
      - type: bind
        source: ${MOUNT_DIR}
        target: /mnt/decypharr
        bind:
          propagation: rshared
      - type: bind
        source: ${DOWNLOADS_DIR}
        target: /data/downloads
    devices:
      - /dev/fuse:/dev/fuse:rwm
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined
    privileged: false
    x-casaos:
      envs:
        - container: TZ
          description:
            en_us: TimeZone
        - container: PUID
          description:
            en_us: User ID for file permissions
        - container: PGID
          description:
            en_us: Group ID for file permissions
      ports:
        - container: "8282"
          description:
            en_us: Decypharr Web UI and qBittorrent API
      volumes:
        - container: /app
          description:
            en_us: Decypharr configuration and cache
        - container: /mnt/decypharr
          description:
            en_us: TorBox rclone mount root
        - container: /data/downloads
          description:
            en_us: Symlink folder for Sonarr and Radarr
x-casaos:
  architectures:
    - amd64
    - arm64
  main: decypharr
  author: Decypharr
  category: Cloud
  title:
    en_us: Decypharr
  description:
    en_us: |
      Decypharr connects Sonarr, Radarr, and other *arr apps to TorBox.
      It emulates qBittorrent, mounts TorBox via embedded rclone, and creates symlinks to cloud files.
  icon: https://raw.githubusercontent.com/sirrobot01/decypharr/main/docs/public/favicon.png
  port_map: "8282"
  scheme: http
  index: /
  hostname: ""
  pre-install-cmd: |
    mkdir -p ${INSTALL_DIR}/config/cache/rclone ${MOUNT_DIR} ${DOWNLOADS_DIR} &&
    findmnt -n ${MOUNT_DIR} >/dev/null 2>&1 || (mount --bind ${MOUNT_DIR} ${MOUNT_DIR} && mount --make-shared ${MOUNT_DIR}) &&
    chown -R \$PUID:\$PGID ${INSTALL_DIR} ${DOWNLOADS_DIR}
EOF
}

write_docker_compose() {
  cat >"${INSTALL_DIR}/docker-compose.yml" <<EOF
services:
  decypharr:
    image: ${IMAGE}
    container_name: decypharr
    restart: unless-stopped
    ports:
      - "8282:8282"
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ_VALUE}
    volumes:
      - ${INSTALL_DIR}/config:/app
      - ${MOUNT_DIR}:/mnt/decypharr:rshared
      - ${DOWNLOADS_DIR}:/data/downloads
    devices:
      - /dev/fuse:/dev/fuse:rwm
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined
EOF
}

write_config() {
  local config_dir="${INSTALL_DIR}/config"

  if [[ -f "${config_dir}/config.json" ]]; then
    log "Existing config found at ${config_dir}/config.json (leaving untouched)."
    return 0
  fi

  if [[ -z "${TORBOX_API_KEY:-}" ]]; then
    log "No API key supplied. Skipping config.json so the setup wizard can run."
    return 0
  fi

  cat >"${config_dir}/config.json" <<EOF
{
  "port": "8282",
  "log_level": "info",
  "use_auth": false,
  "download_folder": "/data/downloads",
  "categories": ["sonarr", "radarr"],
  "debrids": [
    {
      "provider": "torbox",
      "name": "torbox",
      "api_key": "${TORBOX_API_KEY}",
      "folder": "/mnt/decypharr/torbox/__all__",
      "rate_limit": "55/hour",
      "download_uncached": true
    }
  ],
  "mount": {
    "type": "rclone",
    "mount_path": "/mnt/decypharr",
    "rclone": {
      "cache_dir": "/app/cache/rclone",
      "vfs_cache_mode": "writes",
      "vfs_cache_max_size": "10GB",
      "vfs_read_chunk_size": "128MB",
      "vfs_read_ahead": "256MB",
      "buffer_size": "16MB",
      "transfers": 4,
      "uid": ${PUID},
      "gid": ${PGID}
    }
  }
}
EOF
  chmod 600 "${config_dir}/config.json"
  run_root chown "${PUID}:${PGID}" "${config_dir}/config.json" 2>/dev/null || true
  log "Wrote TorBox-ready config with embedded rclone mounting."
}

install_docker() {
  ensure_docker
  install_host_deps
  prepare_directories
  setup_mount_propagation

  if [[ "$IS_CASAOS" == true ]]; then
    write_casaos_compose
    install_mount_systemd
  else
    write_docker_compose
  fi

  write_config

  log "Pulling ${IMAGE}..."
  "${DOCKER_PREFIX[@]}" docker pull "$IMAGE"

  log "Starting Decypharr..."
  (
    cd "$INSTALL_DIR"
    if [[ "$IS_CASAOS" == true ]]; then
      PUID="$PUID" PGID="$PGID" TZ="$TZ_VALUE" "${COMPOSE[@]}" up -d
    else
      "${COMPOSE[@]}" up -d
    fi
  )

  log "Decypharr is running at http://localhost:8282"
  log "Rclone is bundled in the container and mounts TorBox at /mnt/decypharr/torbox"
  if [[ "$IS_CASAOS" == true ]]; then
    log "CasaOS: point Sonarr/Radarr download client to <your-server-ip>:8282"
    log "CasaOS compose file: ${INSTALL_DIR}/docker-compose.yml"
  else
    log "Point Sonarr/Radarr download client to host:8282 (qBittorrent-compatible)"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) err "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

install_binary() {
  local arch release_url tmpdir
  arch=$(detect_arch)
  need_cmd curl
  install_host_deps
  prepare_directories
  setup_mount_propagation

  if [[ "$IS_CASAOS" == true ]]; then
    install_mount_systemd
  fi

  log "Installing rclone..."
  if ! command -v rclone >/dev/null 2>&1; then
    curl -fsSL https://rclone.org/install.sh | run_root bash
  else
    log "rclone already installed: $(rclone version | head -n1)"
  fi

  log "Installing Decypharr binary..."
  tmpdir=$(mktemp -d)
  release_url="https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_Linux_${arch}.tar.gz"
  curl -fsSL "$release_url" -o "${tmpdir}/decypharr.tar.gz"
  tar -xzf "${tmpdir}/decypharr.tar.gz" -C "$tmpdir"
  run_root install -m 0755 "${tmpdir}/decypharr" /usr/local/bin/decypharr
  rm -rf "$tmpdir"

  export DECYPHARR_CONFIG="${INSTALL_DIR}/config"
  write_config

  if [[ -z "${TORBOX_API_KEY:-}" ]]; then
    warn "No TORBOX_API_KEY provided. Run: decypharr --config ${INSTALL_DIR}/config"
    warn "Then complete the setup wizard at http://localhost:8282"
    return 0
  fi

  log "Installed decypharr to /usr/local/bin/decypharr"
  log "Start with: decypharr --config ${INSTALL_DIR}/config"
}

main() {
  detect_casaos
  configure_paths

  log "Decypharr + Rclone installer for TorBox v${VERSION}"
  if [[ "$IS_CASAOS" == true ]]; then
    log "Target platform: CasaOS on Ubuntu"
  fi

  prompt_torbox_key
  verify_torbox_key

  case "$INSTALL_METHOD" in
    docker) install_docker ;;
    binary) install_binary ;;
    *)
      err "Unknown INSTALL_METHOD: ${INSTALL_METHOD} (use docker or binary)"
      exit 1
      ;;
  esac

  cat <<EOF

Done.

Useful paths:
  Install dir:  ${INSTALL_DIR}
  Mount dir:    ${MOUNT_DIR}
  Downloads:    ${DOWNLOADS_DIR}
  Web UI:       http://localhost:8282

TorBox mount path inside Decypharr:
  /mnt/decypharr/torbox/__all__

EOF

  if [[ "$IS_CASAOS" == true ]]; then
    cat <<EOF
CasaOS notes:
  - App data lives under ${INSTALL_DIR}
  - Symlinks are written to ${DOWNLOADS_DIR}
  - In Sonarr/Radarr, set the qBittorrent host to your CasaOS server IP on port 8282
  - You can also import ${INSTALL_DIR}/docker-compose.yml via App Store -> Custom Install

Re-run:
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | TORBOX_API_KEY="your-key" bash
EOF
  else
    cat <<EOF
Re-run:
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | TORBOX_API_KEY="your-key" bash
EOF
  fi
}

main "$@"
