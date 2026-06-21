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

echo "Decypharr ZimaOS installer"
echo "Base directory: ${BASE_DIR}"

mkdir -p "${CONFIG_DIR}" "${MOUNT_DIR}" "${CACHE_DIR}"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${REPO_RAW}/config/config.json.example" -o "${CONFIG_FILE}"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "${CONFIG_FILE}" "${REPO_RAW}/config/config.json.example"
else
  echo "Error: curl or wget is required." >&2
  exit 1
fi

if [ -n "${TORBOX_API_KEY}" ]; then
  if command -v sed >/dev/null 2>&1; then
    # Escape characters that could break sed replacement
    ESCAPED_KEY=$(printf '%s' "${TORBOX_API_KEY}" | sed 's/[\/&]/\\&/g')
    sed -i "s/\"api_key\": \"\"/\"api_key\": \"${ESCAPED_KEY}\"/" "${CONFIG_FILE}"
    echo "Torbox API key written to ${CONFIG_FILE}"
  else
    echo "Warning: sed not found. Set api_key manually in ${CONFIG_FILE}"
  fi
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
