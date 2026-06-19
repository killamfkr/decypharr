#!/usr/bin/env bash
# Decypharr + Rclone quick installer for TorBox
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | bash
#   curl -fsSL ... | TORBOX_API_KEY="your-key" bash
#   curl -fsSL ... | bash -s -- --yes
set -euo pipefail

VERSION="1.0.0"
NON_INTERACTIVE=false
INSTALL_METHOD="${INSTALL_METHOD:-docker}"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/decypharr-torbox}"
MOUNT_DIR="${MOUNT_DIR:-${INSTALL_DIR}/mount}"
IMAGE="${DECYPHARR_IMAGE:-cy01/blackhole:latest}"
PUID="${PUID:-$(id -u)}"
PGID="${PGID:-$(id -g)}"

log() { printf '\033[0;36m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*"; }
err() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Decypharr + Rclone installer for TorBox v${VERSION}

One-liner:
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | bash

With your TorBox API key:
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | TORBOX_API_KEY="your-key" bash

Unattended:
  curl -fsSL ... | TORBOX_API_KEY="your-key" bash -s -- --yes

Environment variables:
  TORBOX_API_KEY       TorBox API key from https://torbox.app/settings
  INSTALL_DIR          Install directory (default: ~/decypharr-torbox)
  MOUNT_DIR            Host mount path for rclone (default: \$INSTALL_DIR/mount)
  DECYPHARR_IMAGE      Docker image (default: cy01/blackhole:latest)
  INSTALL_METHOD       docker (default) or binary
  PUID / PGID          File ownership inside the container

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
    if ! dpkg -s fuse3 >/dev/null 2>&1 && ! dpkg -s libfuse2 >/dev/null 2>&1; then
      log "Installing FUSE packages..."
      run_root apt-get update -qq
      run_root apt-get install -y fuse3 libfuse2 curl ca-certificates
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

setup_mount_propagation() {
  mkdir -p "$MOUNT_DIR"

  if findmnt -n "$MOUNT_DIR" >/dev/null 2>&1; then
    log "Mount propagation already configured at ${MOUNT_DIR}"
    return 0
  fi

  log "Configuring FUSE mount propagation at ${MOUNT_DIR}..."
  run_root mount --bind "$MOUNT_DIR" "$MOUNT_DIR"
  run_root mount --make-shared "$MOUNT_DIR"
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
      - TZ=${TZ:-UTC}
    volumes:
      - ./config:/app
      - ${MOUNT_DIR}:/mnt/decypharr:rshared
      - ./downloads:/data/downloads
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
  mkdir -p "${config_dir}/cache/rclone" "${INSTALL_DIR}/downloads"

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
      "transfers": 4
    }
  }
}
EOF
  chmod 600 "${config_dir}/config.json"
  log "Wrote TorBox-ready config with embedded rclone mounting."
}

install_docker() {
  ensure_docker
  install_host_deps

  log "Creating install directory at ${INSTALL_DIR}"
  mkdir -p "$INSTALL_DIR"
  setup_mount_propagation
  write_docker_compose
  write_config

  log "Pulling ${IMAGE}..."
  "${DOCKER_PREFIX[@]}" docker pull "$IMAGE"

  log "Starting Decypharr..."
  (
    cd "$INSTALL_DIR"
    "${COMPOSE[@]}" up -d
  )

  log "Decypharr is running at http://localhost:8282"
  log "Rclone is bundled in the container and mounts TorBox at /mnt/decypharr/torbox"
  log "Point Sonarr/Radarr download client to host:8282 (qBittorrent-compatible)"
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

  mkdir -p "${INSTALL_DIR}/config" "${INSTALL_DIR}/downloads" "$MOUNT_DIR" "${INSTALL_DIR}/cache/rclone"
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
  log "Decypharr + Rclone installer for TorBox v${VERSION}"
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
  Downloads:    ${INSTALL_DIR}/downloads
  Web UI:       http://localhost:8282

TorBox mount path inside Decypharr:
  /mnt/decypharr/torbox/__all__

Re-run this installer later with:
  curl -fsSL https://raw.githubusercontent.com/sirrobot01/decypharr/main/scripts/install-torbox.sh | TORBOX_API_KEY="your-key" bash
EOF
}

main "$@"
