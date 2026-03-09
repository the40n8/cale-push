#!/usr/bin/env bash
# providers/transmission.sh - Transmission torrent client provider
#
# Required config:
#   TRANSMISSION_HOST="127.0.0.1:9091"
#   TRANSMISSION_AUTH="user:password"

PROVIDER_NAME="transmission"

provider_check() {
    require_cmd transmission-remote
    if [ -z "${TRANSMISSION_HOST:-}" ]; then
        die "TRANSMISSION_HOST not set in config"
    fi
    if [ -z "${TRANSMISSION_AUTH:-}" ]; then
        die "TRANSMISSION_AUTH not set in config"
    fi
}

provider_add_torrent() {
    local torrent_path="$1"
    local save_dir="$2"

    if ! transmission-remote "$TRANSMISSION_HOST" -n "$TRANSMISSION_AUTH" \
        --add "$torrent_path" \
        --download-dir "$save_dir" \
        --no-start-paused 2>&1; then
        return 1
    fi

    # Trigger verification since we already have the data
    local tid
    tid=$(transmission-remote "$TRANSMISSION_HOST" -n "$TRANSMISSION_AUTH" -l | \
        tail -2 | head -1 | awk '{print $1}' | tr -d '*')
    if [ -n "$tid" ] && [ "$tid" != "Sum:" ]; then
        transmission-remote "$TRANSMISSION_HOST" -n "$TRANSMISSION_AUTH" \
            -t "$tid" --verify 2>/dev/null || true
    fi
}
