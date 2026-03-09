#!/usr/bin/env bash
# uploaders/internal.sh - Upload via La Cale internal API (session-based)
#
# Mimics a browser session: altcha PoW login → cookie → POST internal upload endpoint.
# Does NOT require an API key with upload:write scope — uses email/password credentials.
#
# Required config: LACALE_EMAIL, LACALE_PASSWORD, LACALE_URL

UPLOADER_NAME="internal"
_LAST_UPLOAD_TIME=0

# Browser UA to pass Cloudflare checks
_INTERNAL_UA="${BROWSER_UA:-Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0}"
_INTERNAL_COOKIE="${WORK_DIR:-/tmp}/lacale_session.txt"
_INTERNAL_LOGGED_IN=false

uploader_check() {
    [ -z "${LACALE_EMAIL:-}"    ] && die "LACALE_EMAIL not set (required for internal uploader)"
    [ -z "${LACALE_PASSWORD:-}" ] && die "LACALE_PASSWORD not set (required for internal uploader)"
    [ -z "${LACALE_URL:-}"      ] && die "LACALE_URL not set"
    command -v python3 >/dev/null 2>&1 || die "python3 required for altcha PoW (internal uploader)"
}

# Altcha PoW + session login
_internal_login() {
    if [ "$_INTERNAL_LOGGED_IN" = true ]; then
        return 0
    fi

    log "  Logging in to La Cale (session)..."

    local form_loaded_at
    form_loaded_at="$(date +%s)000"

    # Get altcha challenge
    local challenge_json
    challenge_json=$(curl -sf --max-time 15 \
        -A "$_INTERNAL_UA" \
        -c "$_INTERNAL_COOKIE" -b "$_INTERNAL_COOKIE" \
        -H "Accept: application/json" \
        -H "Referer: ${LACALE_URL}/login" \
        --compressed \
        "${LACALE_URL}/api/auth/altcha/challenge?scope=login" 2>/dev/null)

    local altcha_token=""
    if [ -n "$challenge_json" ]; then
        local salt challenge signature
        salt=$(echo "$challenge_json"      | jq -r '.salt')
        challenge=$(echo "$challenge_json" | jq -r '.challenge')
        signature=$(echo "$challenge_json" | jq -r '.signature')

        local maxnum
        maxnum=$(echo "$challenge_json" | jq -r '.maxNumber // 1000000' 2>/dev/null)
        altcha_token=$(python3 -c "
import hashlib, json, base64, sys, time
salt='$salt'; target='$challenge'; sig='$signature'; maxn=int('$maxnum')
t0=time.time()
for n in range(maxn+1):
    if hashlib.sha256((salt+str(n)).encode()).hexdigest()==target:
        took=int((time.time()-t0)*1000)
        print(base64.b64encode(json.dumps({'algorithm':'SHA-256','challenge':target,'number':n,'salt':salt,'signature':sig,'took':took}).encode()).decode())
        sys.exit(0)
sys.exit(1)
" 2>/dev/null) || true
    fi

    # Build login payload
    local login_payload
    if [ -n "$altcha_token" ]; then
        login_payload=$(jq -cn \
            --arg e "$LACALE_EMAIL" \
            --arg p "$LACALE_PASSWORD" \
            --argjson f "$form_loaded_at" \
            --arg a "$altcha_token" \
            '{email:$e, password:$p, formLoadedAt:$f, altcha:$a}')
    else
        login_payload=$(jq -cn \
            --arg e "$LACALE_EMAIL" \
            --arg p "$LACALE_PASSWORD" \
            --argjson f "$form_loaded_at" \
            '{email:$e, password:$p, formLoadedAt:$f}')
    fi

    local login_response http_code body
    login_response=$(curl -si --max-time 30 \
        -A "$_INTERNAL_UA" \
        -c "$_INTERNAL_COOKIE" -b "$_INTERNAL_COOKIE" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Referer: ${LACALE_URL}/login" \
        -H "Origin: ${LACALE_URL}" \
        --compressed \
        -X POST \
        -d "$login_payload" \
        "${LACALE_URL}/api/auth/login" 2>/dev/null)

    http_code=$(echo "$login_response" | grep -oE '^HTTP/[0-9.]+ [0-9]+' | tail -1 | grep -oE '[0-9]+$')
    body=$(echo "$login_response" | sed -n '/^\r\{0,1\}$/,$ p' | tail -n +2)

    if [ "$http_code" = "200" ] || echo "$body" | grep -q '"success"\s*:\s*true\|"user"\s*:'; then
        log "  Login OK"
        _INTERNAL_LOGGED_IN=true
        return 0
    fi

    local err_msg
    err_msg=$(echo "$body" | jq -r '.message // .error // ""' 2>/dev/null)
    die "Login failed (HTTP ${http_code:-?}): ${err_msg:-check LACALE_EMAIL and LACALE_PASSWORD}"
}

# Resolve category ID by slug from /api/internal/categories
uploader_resolve_category() {
    local slug="$1"
    local meta_file="${WORK_DIR}/meta_internal.json"

    _internal_login || return 1

    if [ ! -f "$meta_file" ]; then
        local result
        result=$(curl -sf --max-time 15 \
            -A "$_INTERNAL_UA" \
            -b "$_INTERNAL_COOKIE" -c "$_INTERNAL_COOKIE" \
            -H "Accept: application/json" \
            --compressed \
            "${LACALE_URL}/api/internal/categories" 2>/dev/null)
        [ -n "$result" ] && echo "$result" > "$meta_file"
    fi

    if [ -f "$meta_file" ]; then
        local cat_id
        # Try exact slug match first, then name contains
        cat_id=$(jq -r --arg s "$slug" '
            .. | objects | select(.slug? == $s or (.name? | ascii_downcase | contains($s))) | .id // empty
        ' "$meta_file" 2>/dev/null | head -1)
        [ -n "$cat_id" ] && echo "$cat_id" && return
    fi

    # Config fallback
    case "$slug" in
        *film*|*movie*) echo "${CAT_MOVIES:-}" ;;
        *seri*|*tv*)    echo "${CAT_SERIES:-}" ;;
        *)              echo "" ;;
    esac
}

# Upload torrent via internal API (session-based)
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

    _internal_login || return 1

    # Pre-check: detect infohash duplicate before upload (faster than a 409 on full upload)
    local parse_result
    parse_result=$(curl -sf --max-time 30 \
        -A "$_INTERNAL_UA" \
        -b "$_INTERNAL_COOKIE" -c "$_INTERNAL_COOKIE" \
        -H "Accept: application/json" \
        -H "Referer: ${LACALE_URL}/upload" \
        -H "Origin: ${LACALE_URL}" \
        --compressed \
        -X POST \
        -F "file=@${torrent_path};type=application/x-bittorrent" \
        "${LACALE_URL}/api/internal/torrents/parse" 2>/dev/null)
    if echo "$parse_result" | grep -qi '"duplicate"[[:space:]]*:[[:space:]]*true\|"exists"[[:space:]]*:[[:space:]]*true\|already exist'; then
        err "  Upload rejected: duplicate InfoHash already on La Cale (pre-check)"
        return 1
    fi

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

    # Write description and NFO to temp files to avoid line break corruption
    local desc_file="$WORK_DIR/description.txt"
    local nfo_text_file="$WORK_DIR/nfotext.txt"
    printf '%s' "${description:-}" > "$desc_file"
    if [ -f "$nfo_path" ] && [ -s "$nfo_path" ]; then
        cat "$nfo_path" > "$nfo_text_file"
    else
        printf '' > "$nfo_text_file"
    fi

    local curl_args=(
        curl -si --max-time 120
        -A "$_INTERNAL_UA"
        -b "$_INTERNAL_COOKIE" -c "$_INTERNAL_COOKIE"
        -H "Accept: application/json"
        -H "Accept-Language: fr-FR,fr;q=0.9,en;q=0.8"
        -H "Referer: ${LACALE_URL}/upload"
        -H "Origin: ${LACALE_URL}"
        --compressed
        -X POST
        -F "title=${release_name}"
        -F "categoryId=${category_id}"
        -F "isAnonymous=false"
        -F "file=@${torrent_path};type=application/x-bittorrent"
        -F "nfoText=<${nfo_text_file}"
        -F "description=<${desc_file}"
    )

    if [ -f "$nfo_path" ] && [ -s "$nfo_path" ]; then
        curl_args+=(-F "nfoFile=@${nfo_path};type=text/plain")
    fi

    if [ -n "$tmdb_id" ] && [ "$tmdb_id" != "null" ]; then
        curl_args+=(-F "tmdbId=${tmdb_id}" -F "tmdbType=${tmdb_type}")
    fi

    # Internal API uses termIds[] instead of tags
    if [ -n "$tag_ids" ]; then
        IFS=',' read -ra TIDS <<< "$tag_ids"
        for tid in "${TIDS[@]}"; do
            [ -n "$tid" ] && curl_args+=(-F "termIds[]=$tid")
        done
    fi

    curl_args+=("${LACALE_URL}/api/internal/torrents/upload")

    local response http_code body
    response=$("${curl_args[@]}" 2>/dev/null)
    http_code=$(echo "$response" | grep -oE '^HTTP/[0-9.]+ [0-9]+' | tail -1 | grep -oE '[0-9]+$')
    body=$(echo "$response" | sed -n '/^\r\{0,1\}$/,$ p' | tail -n +2)

    _LAST_UPLOAD_TIME=$(date +%s)

    # Check success
    local upload_ok=false link=""
    if echo "$body" | grep -q '"success"'; then
        upload_ok=$(echo "$body" | jq -r '.success // false' 2>/dev/null)
        link=$(echo "$body" | jq -r '.link // ""' 2>/dev/null)
    fi
    # Fallback: HTTP 200 with torrentId/slug in body
    if [ "$upload_ok" != "true" ] && [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q '"torrentId"\|"infoHash"\|"slug"'; then
            upload_ok="true"
            link=$(echo "$body" | jq -r '.link // .data.link // ""' 2>/dev/null)
        fi
    fi

    if [ "$upload_ok" = "true" ]; then
        [ -n "$link" ] && [ "$link" != "null" ] && log "  URL: $link"
        return 0
    fi

    # Session may have expired — reset and report
    _INTERNAL_LOGGED_IN=false
    local err_msg
    err_msg=$(echo "$body" | jq -r '.message // .error // ""' 2>/dev/null)
    [ -z "$err_msg" ] && err_msg=$(echo "$body" | head -c 300)

    case "$http_code" in
        401|403) err "  Upload rejected (HTTP $http_code): session expired or unauthorized" ;;
        409)     err "  Upload rejected (409): duplicate — same InfoHash already on La Cale" ;;
        429)     err "  Upload rejected (429): rate limit hit — increase UPLOAD_DELAY" ;;
        *)       err "  Upload failed (HTTP ${http_code:-?}): $err_msg" ;;
    esac
    return 1
}
