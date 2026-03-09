#!/usr/bin/env bash
# core.sh - Logging, utilities, work directory management

UPLOADED=0
SKIPPED=0
ERRORS=0
DRY_RUN=false

# File logging (set LOG_FILE in config to enable)
_log_to_file() {
    if [ -n "${LOG_FILE:-}" ]; then
        local dir
        dir=$(dirname "$LOG_FILE")
        [ -d "$dir" ] || mkdir -p "$dir"
        echo "$*" >> "$LOG_FILE"
    fi
}

log()  { local msg="[$(date '+%H:%M:%S')] $*"; echo "$msg"; _log_to_file "$msg"; }
warn() { local msg="[$(date '+%H:%M:%S')] WARN: $*"; echo "$msg"; _log_to_file "$msg"; }
err()  { local msg="[$(date '+%H:%M:%S')] ERROR: $*"; echo "$msg" >&2; _log_to_file "$msg"; }
die()  { err "$*"; cleanup; exit 1; }

init_workdir() {
    WORK_DIR="/tmp/lacale_upload_$$"
    mkdir -p "$WORK_DIR"
    touch "$HISTORY_FILE"
    touch "$CACHE_FILE"
}

cleanup() {
    [ -n "${WORK_DIR:-}" ] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

check_dependencies() {
    require_cmd curl
    require_cmd jq
    require_cmd mktorrent
    require_cmd mediainfo
}

# HTTP request with retry and backoff
# Usage: curl_retry curl [args...]
# Retries on failure up to MAX_RETRIES times with exponential backoff
curl_retry() {
    local max_retries="${MAX_RETRIES:-3}"
    local attempt=0
    local output

    while [ "$attempt" -lt "$max_retries" ]; do
        attempt=$((attempt + 1))
        if output=$("$@" 2>&1); then
            echo "$output"
            return 0
        fi
        if [ "$attempt" -lt "$max_retries" ]; then
            local wait=$((2 ** attempt))
            warn "Request failed (attempt $attempt/$max_retries), retrying in ${wait}s..."
            sleep "$wait"
        fi
    done

    echo "$output"
    return 1
}

# Check if a TMDB ID or title is in the exclude list
is_excluded() {
    local tmdb_id="$1" title="$2"
    local exclude_file="${EXCLUDE_FILE:-}"

    { [ -z "$exclude_file" ] || [ ! -f "$exclude_file" ]; } && return 1

    if [ -n "$tmdb_id" ] && [ "$tmdb_id" != "null" ]; then
        grep -qxF "$tmdb_id" "$exclude_file" 2>/dev/null && return 0
    fi

    if [ -n "$title" ]; then
        grep -qiF "$title" "$exclude_file" 2>/dev/null && return 0
    fi

    return 1
}

# Map quality name to a numeric rank for filtering
_quality_rank() {
    local q="$1"
    case "$q" in
        *2160*|*4K*|*UHD*) echo 4 ;;
        *1080*)            echo 3 ;;
        *720*)             echo 2 ;;
        *480*|*SD*)        echo 1 ;;
        *)                 echo 0 ;;
    esac
}

# Check if quality meets minimum threshold
meets_min_quality() {
    local quality="$1"
    local min="${MIN_QUALITY:-}"

    [ -z "$min" ] && return 0

    local rank min_rank
    rank=$(_quality_rank "$quality")
    min_rank=$(_quality_rank "$min")

    [ "$rank" -ge "$min_rank" ]
}

# Map a path from Radarr/Sonarr to the local filesystem
# Uses PATH_MAP config: "source:target" (e.g., "/movies:/media/movies")
# Multiple mappings separated by commas: "/movies:/media/movies,/tv:/media/tv"
map_path() {
    local path="$1"
    local path_map="${PATH_MAP:-}"

    [ -z "$path_map" ] && echo "$path" && return

    IFS=',' read -ra mappings <<< "$path_map"
    for mapping in "${mappings[@]}"; do
        local src="${mapping%%:*}"
        local dst="${mapping#*:}"
        if [[ "$path" == "$src"* ]]; then
            echo "${dst}${path#"$src"}"
            return
        fi
    done

    echo "$path"
}
