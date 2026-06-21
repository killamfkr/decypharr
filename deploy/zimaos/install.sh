#!/bin/sh
set -e

# One-command ZimaOS setup for Decypharr (Torbox + rclone).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos/install.sh | sh
# Or with your API key:
#   TORBOX_API_KEY=your_key curl -fsSL .../install.sh | sh

REPO_RAW="https://raw.githubusercontent.com/killamfkr/decypharr/cursor/zimaos-torbox-rclone-edec/deploy/zimaos"
BASE_DIR="${DECYPHARR_BASE_DIR:-/DATA/AppData/decypharr}"

CONFIG_DIR="${BASE_DIR}/config"
MOUNT_DIR="${BASE_DIR}/mount"
CACHE_DIR="${BASE_DIR}/cache"
CONFIG_FILE="${CONFIG_DIR}/config.json"
TMP_CONFIG="/tmp/decypharr-config.json"

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "Error: need root permissions to create ${BASE_DIR}" >&2
    echo "Run: sudo mkdir -p ${CONFIG_DIR} ${MOUNT_DIR} ${CACHE_DIR}" >&2
    exit 1
  fi
}

echo "Decypharr ZimaOS installer"
echo "Base directory: ${BASE_DIR}"

run_root mkdir -p "${CONFIG_DIR}" "${MOUNT_DIR}" "${CACHE_DIR}"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${REPO_RAW}/config/config.json.example" -o "${TMP_CONFIG}"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "${TMP_CONFIG}" "${REPO_RAW}/config/config.json.example"
else
  echo "Error: curl or wget is required." >&2
  exit 1
fi

if [ -n "${TORBOX_API_KEY}" ] && command -v sed >/dev/null 2>&1; then
  ESCAPED_KEY=$(printf '%s' "${TORBOX_API_KEY}" | sed 's/[\/&]/\\&/g')
  sed -i "s/\"api_key\": \"\"/\"api_key\": \"${ESCAPED_KEY}\"/" "${TMP_CONFIG}"
fi

run_root cp "${TMP_CONFIG}" "${CONFIG_FILE}"
run_root chmod 644 "${CONFIG_FILE}"
rm -f "${TMP_CONFIG}"

if [ -n "${TORBOX_API_KEY}" ]; then
  echo "Torbox API key written to ${CONFIG_FILE}"
else
  echo ""
  echo "Next: edit ${CONFIG_FILE} and set your Torbox api_key,"
  echo "      or set TORBOX_API_KEY in the container environment."
fi

echo ""
echo "Created:"
echo "  ${CONFIG_FILE}"
echo "  ${MOUNT_DIR}"
echo "  ${CACHE_DIR}"
echo ""
echo "Now install the app in ZimaOS using deploy/zimaos/docker-compose.yml"
echo "and point the three volume paths at:"
echo "  config -> ${CONFIG_DIR}"
echo "  mount  -> ${MOUNT_DIR}"
echo "  cache  -> ${CACHE_DIR}"
