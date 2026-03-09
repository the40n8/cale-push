#!/usr/bin/env bash
# providers/qbittorrent.sh - qBittorrent torrent client provider
#
# Required config:
#   QBIT_HOST="127.0.0.1:8080"
#   QBIT_USER="admin"
#   QBIT_PASS="adminadmin"

PROVIDER_NAME="qbittorrent"

# Authenticate and store session cookie
_qbit_login() {
    local cookie_jar="$WORK_DIR/qbit_cookie"
    local resp
    resp=$(curl -sf -c "$cookie_jar" -X POST \
        "http://${QBIT_HOST}/api/v2/auth/login" \
        -d "username=${QBIT_USER}&password=${QBIT_PASS}" 2>&1)

    if [ "$resp" != "Ok." ]; then
        return 1
    fi
}

provider_check() {
    [ -z "${QBIT_HOST:-}" ] && die "QBIT_HOST not set in config"
    [ -z "${QBIT_USER:-}" ] && die "QBIT_USER not set in config"
    [ -z "${QBIT_PASS:-}" ] && die "QBIT_PASS not set in config"
}

provider_add_torrent() {
    local torrent_path="$1"
    local save_dir="$2"
    local cookie_jar="$WORK_DIR/qbit_cookie"

    # Login if no cookie yet
    if [ ! -f "$cookie_jar" ]; then
        _qbit_login || die "qBittorrent login failed (check QBIT_HOST/USER/PASS)"
    fi

    local http_code
    http_code=$(curl -sf -o /dev/null -w '%{http_code}' \
        -b "$cookie_jar" \
        -X POST "http://${QBIT_HOST}/api/v2/torrents/add" \
        -F "torrents=@${torrent_path}" \
        -F "savepath=${save_dir}" \
        -F "skip_checking=true" 2>&1)

    # Re-login on 403 and retry once
    if [ "$http_code" = "403" ]; then
        _qbit_login || die "qBittorrent re-login failed"
        http_code=$(curl -sf -o /dev/null -w '%{http_code}' \
            -b "$cookie_jar" \
            -X POST "http://${QBIT_HOST}/api/v2/torrents/add" \
            -F "torrents=@${torrent_path}" \
            -F "savepath=${save_dir}" \
            -F "skip_checking=true" 2>&1)
    fi

    [ "$http_code" = "200" ] || return 1
}
