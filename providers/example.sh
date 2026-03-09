#!/usr/bin/env bash
# providers/example.sh - Template for creating a custom torrent client provider
#
# To create a provider for your torrent client:
#   1. Copy this file to providers/yourprovider.sh
#   2. Implement the two functions below
#   3. Set TORRENT_PROVIDER="yourprovider" in your config
#
# The provider will be sourced by the main script, so you have access
# to all config variables and lib functions (log, warn, err, die, require_cmd).

PROVIDER_NAME="example"

# Called once at startup to validate provider config
provider_check() {
    # Verify required commands exist
    # require_cmd qbittorrent-nox

    # Verify required config variables
    # [ -z "${QBIT_HOST:-}" ] && die "QBIT_HOST not set in config"
    # [ -z "${QBIT_USER:-}" ] && die "QBIT_USER not set in config"

    die "Example provider is not meant to be used directly. Copy it and implement your own."
}

# Add a torrent file and start seeding
# Args:
#   $1 - Path to the .torrent file
#   $2 - Directory where the data already exists (for seeding)
provider_add_torrent() {
    local torrent_path="$1"
    local save_dir="$2"

    # Example for qBittorrent:
    # curl -sf -X POST "http://${QBIT_HOST}/api/v2/torrents/add" \
    #     --cookie "$(cat "$WORK_DIR/qbit_cookie")" \
    #     -F "torrents=@${torrent_path}" \
    #     -F "savepath=${save_dir}" \
    #     -F "skip_checking=true"

    die "Example provider: provider_add_torrent not implemented"
}
