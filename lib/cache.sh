#!/usr/bin/env bash
# cache.sh - Local cache for La Cale API responses
# Avoids hammering the API by caching TMDB ID lookups
# Format: TSV with key, count, timestamp

_cache_get() {
    local key="$1"
    local now
    now=$(date +%s)
    local line
    line=$(grep -m1 "^${key}	" "$CACHE_FILE" 2>/dev/null) || return 1
    local cached_count cached_ts
    cached_count=$(echo "$line" | cut -f2)
    cached_ts=$(echo "$line" | cut -f3)
    local ttl
    [ "$cached_count" -gt 0 ] 2>/dev/null && ttl=$CACHE_TTL_PRESENT || ttl=$CACHE_TTL_ABSENT
    if [ $((now - cached_ts)) -lt "$ttl" ]; then
        echo "$cached_count"
        return 0
    fi
    return 1
}

_cache_set() {
    local key="$1" count="$2"
    local now
    now=$(date +%s)
    grep -v "^${key}	" "$CACHE_FILE" > "${CACHE_FILE}.tmp" 2>/dev/null || true
    printf '%s\t%s\t%s\n' "$key" "$count" "$now" >> "${CACHE_FILE}.tmp"
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
}

# Count how many releases exist on La Cale for a given TMDB ID or title
# Returns: integer count (0 = not on La Cale)
count_releases_lacale() {
    local tmdb_id="$1" title="$2"
    local cache_key="${tmdb_id:-title:${title}}"

    local cached
    if cached=$(_cache_get "$cache_key"); then
        echo "$cached"
        return 0
    fi

    # Rate limit between search API calls
    sleep "${SEARCH_DELAY:-0.3}"

    local count="0"
    if [ -n "$tmdb_id" ] && [ "$tmdb_id" != "null" ] && [ "$tmdb_id" != "0" ]; then
        local results
        results=$(curl_retry curl -sf --max-time 15 \
            -H "X-Api-Key: ${LACALE_API_KEY}" \
            "${LACALE_URL}/api/external?tmdbId=${tmdb_id}" 2>/dev/null)
        if [ -n "$results" ]; then
            count=$(echo "$results" | jq 'length' 2>/dev/null || echo "0")
        fi
    else
        local query
        query=$(printf '%s' "$title" | sed 's/ /+/g')
        local results
        results=$(curl_retry curl -sf --max-time 15 \
            -H "X-Api-Key: ${LACALE_API_KEY}" \
            "${LACALE_URL}/api/external?q=${query}" 2>/dev/null)
        if [ -n "$results" ]; then
            count=$(echo "$results" | jq 'length' 2>/dev/null || echo "0")
        fi
    fi

    _cache_set "$cache_key" "$count"
    echo "$count"
}

# Force fresh API check (invalidates cache first)
# Used just before upload to catch last-minute duplicates
count_releases_lacale_fresh() {
    local tmdb_id="$1" title="$2"
    local cache_key="${tmdb_id:-title:${title}}"

    grep -v "^${cache_key}	" "$CACHE_FILE" > "${CACHE_FILE}.tmp" 2>/dev/null || true
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"

    count_releases_lacale "$tmdb_id" "$title"
}
