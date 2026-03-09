#!/usr/bin/env bash
# uploaders/example.sh - Template for custom upload methods
#
# Copy this file to uploaders/mymethod.sh and implement the three functions below.
# Then set UPLOAD_METHOD="mymethod" in your config.
#
# Interface contract:
#   uploader_check()                   → validate config, die if something is missing
#   uploader_resolve_category(slug)    → echo category ID for "films" or "series"
#   uploader_upload(args...)           → perform upload, return 0 on success

UPLOADER_NAME="example"

uploader_check() {
    # Validate required config keys here
    # Use: die "MY_KEY not set" to abort
    :
}

# Resolve a category ID from a slug ("films" or "series")
# Echo the category ID and return 0, or echo empty string if not found
uploader_resolve_category() {
    local slug="$1"
    # Example: return hardcoded IDs
    case "$slug" in
        *film*|*movie*) echo "${CAT_MOVIES:-}" ;;
        *seri*|*tv*)    echo "${CAT_SERIES:-}" ;;
        *)              echo "" ;;
    esac
}

# Perform the actual upload
# Args:
#   $1 torrent_path  — absolute path to the .torrent file
#   $2 release_name  — formatted release name (La Cale naming rules)
#   $3 category_id   — resolved by uploader_resolve_category()
#   $4 nfo_path      — absolute path to the .nfo file (may be empty)
#   $5 description   — BBCode description string
#   $6 tmdb_id       — TMDB ID (may be empty)
#   $7 tmdb_type     — "MOVIE" or "TV"
#   $8 tag_ids       — comma-separated tag IDs from tags.sh
#
# Return 0 on success, 1 on failure
uploader_upload() {
    local torrent_path="$1"
    local release_name="$2"
    local category_id="$3"
    local nfo_path="$4"
    local description="$5"
    local tmdb_id="$6"
    local tmdb_type="$7"
    local tag_ids="$8"

    # Implement your upload logic here
    log "  [example uploader] Would upload: $release_name"
    return 0
}
