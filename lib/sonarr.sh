#!/usr/bin/env bash
# sonarr.sh - Sonarr integration (fetch series, process episodes)

fetch_sonarr_series() {
    local output="$1"
    curl -sf -H "X-Api-Key: $SONARR_API_KEY" \
        "${SONARR_URL}/api/v3/series" > "$output" \
        || die "Cannot reach Sonarr at $SONARR_URL"
}

fetch_sonarr_episodes() {
    local series_id="$1"
    curl -sf -H "X-Api-Key: $SONARR_API_KEY" \
        "${SONARR_URL}/api/v3/episode?seriesId=${series_id}" \
        || die "Cannot fetch episodes for series $series_id from Sonarr"
}

process_episode() {
    local episode_json="$1"
    local series_json="$2"

    local series_title series_year
    series_title=$(echo "$series_json" | jq -r '.title')
    series_year=$(echo "$series_json" | jq -r '.year')

    local ep_path filename season_num ep_num
    ep_path=$(echo "$episode_json" | jq -r '.episodeFile.path // ""')
    ep_path=$(map_path "$ep_path")
    filename=$(basename "$ep_path")
    season_num=$(echo "$episode_json" | jq -r '.seasonNumber')
    ep_num=$(echo "$episode_json" | jq -r '.episodeNumber')

    { [ -z "$ep_path" ] || [ ! -f "$ep_path" ]; } && return 1

    # Exclude list check
    local tvdb_id_early
    tvdb_id_early=$(echo "$series_json" | jq -r '.tvdbId // ""')
    if is_excluded "$tvdb_id_early" "$series_title"; then
        log "  $series_title: excluded"; SKIPPED=$((SKIPPED+1)); return 0
    fi

    local quality_name video_codec audio_codec audio_langs dyn_range video_depth subtitles release_group
    quality_name=$(echo "$episode_json" | jq -r '.episodeFile.quality.quality.name // ""')
    video_codec=$(echo "$episode_json" | jq -r '.episodeFile.mediaInfo.videoCodec // ""')
    audio_codec=$(echo "$episode_json" | jq -r '.episodeFile.mediaInfo.audioCodec // ""')
    audio_langs=$(echo "$episode_json" | jq -r '.episodeFile.mediaInfo.audioLanguages // ""')
    dyn_range=$(echo "$episode_json" | jq -r '.episodeFile.mediaInfo.videoDynamicRange // ""')
    video_depth=$(echo "$episode_json" | jq -r '.episodeFile.mediaInfo.videoBitDepth // ""')
    subtitles=$(echo "$episode_json" | jq -r '.episodeFile.mediaInfo.subtitles // ""')
    release_group=$(echo "$episode_json" | jq -r '.episodeFile.releaseGroup // ""')

    local se_tag
    se_tag=$(printf "S%02dE%02d" "$season_num" "$ep_num")

    local release_name
    release_name=$(build_release_name "$series_title" "$se_tag" "$filename" \
        "$quality_name" "$video_codec" "$audio_langs" "$dyn_range" "$release_group" "$audio_codec")

    log "  $series_title $se_tag -> $release_name"

    if grep -qiF "$release_name" "$HISTORY_FILE" 2>/dev/null; then
        log "  SKIP: already in history"
        SKIPPED=$((SKIPPED+1)); return 0
    fi

    # Check La Cale
    local tvdb_id
    tvdb_id=$(echo "$series_json" | jq -r '.tvdbId // ""')
    log "  Checking La Cale..."
    local release_count
    release_count=$(count_releases_lacale "$tvdb_id" "$series_title")
    log "  Found $release_count release(s) on La Cale"

    local pass_mode="${PASS_MODE:-unique}"
    if [ "$pass_mode" = "unique" ] && [ "$release_count" -gt 0 ]; then
        log "  SKIP: already on La Cale ($release_count release(s)), unique mode"
        SKIPPED=$((SKIPPED+1)); return 0
    fi

    # NFO + torrent
    local nfo_path="$WORK_DIR/${release_name}.nfo"
    local torrent_path="$WORK_DIR/${release_name}.torrent"
    mediainfo "$ep_path" > "$nfo_path" 2>/dev/null || true
    sed -i'' "s|Complete name.*|Complete name                            : $filename|g" "$nfo_path" 2>/dev/null || true

    log "  Creating torrent..."
    if ! create_torrent "$ep_path" "$torrent_path" > /dev/null 2>&1; then
        err "  Failed to create torrent"; return 1
    fi

    local tag_ids
    tag_ids=$(get_tag_ids "$filename" "$quality_name" "$video_codec" \
        "$audio_codec" "$audio_langs" "$dyn_range" "$video_depth" "$subtitles")

    local overview
    overview=$(echo "$series_json" | jq -r '.overview // ""')
    local description
    description=$(printf '[center]\n[size=6][color=#eab308][b]%s %s[/b][/color][/size]\n\n' "$series_title" "$se_tag")
    if [ -n "$overview" ] && [ "$overview" != "null" ]; then
        description="${description}$(printf '[quote]%s[/quote]\n\n' "$overview")"
    fi
    description="${description}$(printf '\n[i]Upload auto - lacale-uploader[/i]\n[/center]')"

    # Fresh re-check
    local fresh_count
    fresh_count=$(count_releases_lacale_fresh "$tvdb_id" "$series_title")
    if [ "$pass_mode" = "unique" ] && [ "$fresh_count" -gt 0 ]; then
        log "  SKIP: appeared on La Cale during processing"
        SKIPPED=$((SKIPPED+1)); return 0
    fi

    # Quality filter
    if ! meets_min_quality "$quality_name"; then
        log "  $series_title $se_tag: below min quality ($quality_name < ${MIN_QUALITY:-})"; SKIPPED=$((SKIPPED+1)); return 0
    fi

    # Dry run stops here
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY-RUN] Would upload: $release_name"
        UPLOADED=$((UPLOADED+1)); return 0
    fi

    # Resolve category ID via active uploader
    local cat_id
    cat_id=$(uploader_resolve_category "series")
    [ -z "$cat_id" ] && { err "  Cannot resolve category ID for series (check /api/internal/categories or set CAT_SERIES)"; return 1; }

    log "  Uploading to La Cale (${UPLOAD_METHOD:-internal})..."
    if uploader_upload "$torrent_path" "$release_name" "$cat_id" "$nfo_path" \
        "$description" "" "TV" "$tag_ids"; then
        log "  Upload OK"
        local save_dir
        save_dir=$(dirname "$ep_path")
        provider_add_torrent "$torrent_path" "$save_dir" >/dev/null 2>&1 || true
        echo "$release_name" >> "$HISTORY_FILE"
        UPLOADED=$((UPLOADED+1))
        notify_upload_ok "$release_name"
    else
        ERRORS=$((ERRORS+1))
        notify_upload_fail "$release_name"
    fi
}
