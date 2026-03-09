#!/usr/bin/env bash
set -euo pipefail

# docker-entrypoint.sh - Entry point for cale-push Docker container
#
# Handles path mapping and config resolution before calling cale-push.
#
# Expected volumes:
#   /config  - Config directory (~/.config/lacale/)
#   /media   - Media root (Radarr/Sonarr files, read-only)
#   /torrents - Torrent output directory (shared with torrent client)

# ---- Resolve config ----
# Priority: LACALE_CONFIG env > /config/config > /config/config.local
if [ -z "${LACALE_CONFIG:-}" ]; then
    if [ -f /config/config ]; then
        export LACALE_CONFIG=/config/config
    elif [ -f /config/config.local ]; then
        export LACALE_CONFIG=/config/config.local
    fi
fi

# ---- Ensure writable data paths exist ----
mkdir -p /data

# Default data paths inside container (can be overridden in config)
export HOME="${HOME:-/data}"
export HISTORY_FILE="${HISTORY_FILE:-/config/uploaded.txt}"
export CACHE_FILE="${CACHE_FILE:-/config/cache.tsv}"

# ---- Run cale-push ----
exec /opt/cale-push/cale-push "$@"
