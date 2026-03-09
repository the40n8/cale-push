#!/usr/bin/env bash
# api.sh - La Cale API utilities (search verification, torrent creation, slot check)
# Upload logic lives in uploaders/*.sh — loaded via UPLOAD_METHOD config.
# API docs: https://la-cale.space/faq/api

# Verify API key is valid
verify_api_key() {
    local result
    result=$(curl -sf --max-time 10 \
        -H "X-Api-Key: ${LACALE_API_KEY}" \
        "${LACALE_URL}/api/external?q=test" 2>/dev/null)
    if [ -z "$result" ]; then
        die "API key invalid or La Cale unreachable"
    fi
    log "API key OK"
}

# Create .torrent file
create_torrent() {
    local file_path="$1"
    local output_path="$2"
    mktorrent -p -s "lacale" -a "$TRACKER_URL" -o "$output_path" "$file_path" 2>&1
}

# Check if upload slot is available (requires session login + altcha PoW)
# Returns 0 if slot available, 1 if limit reached
check_upload_slot() {
    if [ -z "${LACALE_EMAIL:-}" ] || [ -z "${LACALE_PASSWORD:-}" ]; then
        warn "LACALE_EMAIL/LACALE_PASSWORD not set, skipping slot check"
        return 0
    fi

    local cookie="$WORK_DIR/slot_cookies.txt"

    local challenge_json
    challenge_json=$(curl -sf --max-time 15 \
        -c "$cookie" -b "$cookie" \
        -H "Accept: application/json" \
        "${LACALE_URL}/api/auth/altcha/challenge?scope=login" 2>/dev/null)

    if [ -z "$challenge_json" ]; then
        warn "Could not get altcha challenge, proceeding anyway"
        return 0
    fi

    local salt challenge signature
    salt=$(echo "$challenge_json"      | jq -r '.salt')
    challenge=$(echo "$challenge_json" | jq -r '.challenge')
    signature=$(echo "$challenge_json" | jq -r '.signature')

    local maxnum
    maxnum=$(echo "$challenge_json" | jq -r '.maxNumber // 1000000' 2>/dev/null)
    local token
    token=$(python3 -c "
import hashlib, json, base64, sys, time
salt='$salt'; target='$challenge'; sig='$signature'; maxn=int('$maxnum')
t0=time.time()
for n in range(maxn+1):
    if hashlib.sha256((salt+str(n)).encode()).hexdigest()==target:
        took=int((time.time()-t0)*1000)
        print(base64.b64encode(json.dumps({'algorithm':'SHA-256','challenge':target,'number':n,'salt':salt,'signature':sig,'took':took}).encode()).decode())
        sys.exit(0)
sys.exit(1)
" 2>/dev/null) || { warn "PoW failed, proceeding anyway"; return 0; }

    local payload
    payload=$(jq -cn --arg e "$LACALE_EMAIL" --arg p "$LACALE_PASSWORD" \
        --arg a "$token" '{email:$e, password:$p, altcha:$a}')

    curl -sf --max-time 15 -c "$cookie" -b "$cookie" \
        -H "Content-Type: application/json" \
        -X POST -d "$payload" \
        "${LACALE_URL}/api/auth/login" > /dev/null 2>&1

    local upload_page
    upload_page=$(curl -sf --max-time 15 -b "$cookie" -c "$cookie" \
        "${LACALE_URL}/upload" 2>/dev/null)

    if [ -z "$upload_page" ]; then
        warn "Could not load /upload page, proceeding anyway"
        return 0
    fi

    local pending_info
    pending_info=$(echo "$upload_page" | grep -oP 'En Attente.*?\d+ / \d+' | grep -oP '\d+ / \d+' | tail -1)

    if [ -z "$pending_info" ]; then
        warn "Could not parse pending info, proceeding anyway"
        return 0
    fi

    local current max
    current=$(echo "$pending_info" | cut -d'/' -f1 | tr -d ' ')
    max=$(echo "$pending_info"     | cut -d'/' -f2 | tr -d ' ')

    log "  Upload slots: $current / $max pending"

    if [ "$current" -ge "$max" ]; then
        log "  Limit reached ($current/$max) - no upload slot available"
        return 1
    fi

    log "  Slot available ($current/$max)"
    return 0
}
