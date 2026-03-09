#!/usr/bin/env bash
# uploaders/external.sh - Upload via La Cale external API
# API docs: https://la-cale.space/faq/api
#
# Required config: LACALE_API_KEY, LACALE_URL
# Status: pending full activation on La Cale side (upload:write scope)

UPLOADER_NAME="external"
_LAST_UPLOAD_TIME=0

uploader_check() {
    [ -z "${LACALE_API_KEY:-}" ] && die "LACALE_API_KEY not set"
    [ -z "${LACALE_URL:-}" ]     && die "LACALE_URL not set"
}

# Resolve category ID by slug from /api/external/meta
uploader_resolve_category() {
    local slug="$1"
    local meta_file="${WORK_DIR}/meta_external.json"

    if [ ! -f "$meta_file" ]; then
        local result
        result=$(curl -sf --max-time 15 \
            -H "X-Api-Key: ${LACALE_API_KEY}" \
            "${LACALE_URL}/api/external/meta" 2>/dev/null)
        [ -n "$result" ] && echo "$result" > "$meta_file"
    fi

    if [ -f "$meta_file" ]; then
        local cat_id
        cat_id=$(jq -r --arg s "$slug" '
            .categories[]?.children[]? | select(.slug == $s or (.name | ascii_downcase | contains($s))) | .id // empty
        ' "$meta_file" 2>/dev/null | head -1)
        if [ -z "$cat_id" ]; then
            cat_id=$(jq -r --arg s "$slug" '
                .categories[]? | select(.slug == $s or (.name | ascii_downcase | contains($s))) | .id // empty
            ' "$meta_file" 2>/dev/null | head -1)
        fi
        [ -n "$cat_id" ] && echo "$cat_id" && return
    fi

    # Config fallback
    case "$slug" in
        *film*|*movie*) echo "${CAT_MOVIES:-}" ;;
        *seri*|*tv*)    echo "${CAT_SERIES:-}" ;;
        *)              echo "" ;;
    esac
}

# Upload torrent to La Cale via external API
# Args: torrent_path release_name category_id nfo_path description tmdb_id tmdb_type tag_ids
uploader_upload() {
    local torrent_path="$1"
    local release_name="$2"
    local category_id="$3"
    local nfo_path="$4"
    local description="$5"
    local tmdb_id="$6"
    local tmdb_type="$7"
    local tag_ids="$8"

    # Rate limit
    local delay="${UPLOAD_DELAY:-2}"
    if [ "${_LAST_UPLOAD_TIME:-0}" -gt 0 ]; then
        local now elapsed
        now=$(date +%s)
        elapsed=$((now - _LAST_UPLOAD_TIME))
        if [ "$elapsed" -lt "$delay" ]; then
            sleep $((delay - elapsed))
        fi
    fi

    local curl_args=(
        curl -sw $'\n%{http_code}' --max-time 120
        -H "X-Api-Key: ${LACALE_API_KEY}"
        -H "Accept: application/json"
        -X POST
        -F "title=${release_name}"
        -F "categoryId=${category_id}"
        -F "file=@${torrent_path};type=application/x-bittorrent"
    )

    if [ -n "$description" ]; then
        local desc_file="$WORK_DIR/description.txt"
        printf '%s' "$description" > "$desc_file"
        curl_args+=(-F "description=<${desc_file}")
    fi

    if [ -n "$tmdb_id" ] && [ "$tmdb_id" != "null" ]; then
        curl_args+=(-F "tmdbId=${tmdb_id}" -F "tmdbType=${tmdb_type}")
    fi

    if [ -f "$nfo_path" ] && [ -s "$nfo_path" ]; then
        curl_args+=(-F "nfoFile=@${nfo_path};type=text/plain")
    fi

    if [ -n "$tag_ids" ]; then
        IFS=',' read -ra TIDS <<< "$tag_ids"
        for tid in "${TIDS[@]}"; do
            [ -n "$tid" ] && curl_args+=(-F "tags=$tid")
        done
    fi

    curl_args+=("${LACALE_URL}/api/external/upload")

    local response http_code body
    response=$("${curl_args[@]}")
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    _LAST_UPLOAD_TIME=$(date +%s)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        if echo "$body" | jq -e '.success // .id // .slug' >/dev/null 2>&1; then
            local link
            link=$(echo "$body" | jq -r '.link // ""' 2>/dev/null)
            [ -n "$link" ] && [ "$link" != "null" ] && log "  URL: $link"
            return 0
        fi
    fi

    case "$http_code" in
        400) err "  Upload rejected (400): $(echo "$body" | jq -r '.message // .error // empty' 2>/dev/null | head -c 200)" ;;
        401) err "  Upload rejected (401): API key missing" ;;
        403) err "  Upload rejected (403): invalid API key or missing upload:write scope" ;;
        409) err "  Upload rejected (409): duplicate — same InfoHash already on La Cale" ;;
        429) err "  Upload rejected (429): rate limit hit — increase UPLOAD_DELAY" ;;
        *)   err "  Upload failed (HTTP $http_code): $(echo "$body" | head -c 300)" ;;
    esac
    return 1
}
