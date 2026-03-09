#!/usr/bin/env bash
# radarr.sh - Radarr integration (fetch movies, process uploads)

fetch_radarr_movies() {
    local output="$1"
    curl -sf -H "X-Api-Key: $RADARR_API_KEY" \
        "${RADARR_URL}/api/v3/movie" > "$output" \
        || die "Cannot reach Radarr at $RADARR_URL"
}

# Build BBCode description for a movie
_movie_description() {
    local title="$1" year="$2" overview="$3" genres="$4" rating="$5" cover_url="${6:-}"
    local desc
    desc=$(printf '[center]\n')
    if [ -n "$cover_url" ] && [ "$cover_url" != "null" ]; then
        case "$cover_url" in
            http*) : ;;
            *) cover_url="https://image.tmdb.org/t/p/w500${cover_url}" ;;
        esac
        desc="${desc}$(printf '[img]%s[/img]\n\n' "$cover_url")"
    fi
    desc="${desc}$(printf '[size=6][color=#eab308][b]%s (%s)[/b][/color][/size]\n\n' "$title" "$year")"
    if [ -n "$overview" ] && [ "$overview" != "null" ]; then
        desc="${desc}$(printf '[quote]%s[/quote]\n\n' "$overview")"
    fi
    desc="${desc}$(printf '[b]Genre :[/b] %s\n' "${genres:-N/A}")"
    desc="${desc}$(printf '[b]Note :[/b] %s/10\n' "$rating")"
    desc="${desc}$(printf '\n[i]Upload auto - lacale-uploader[/i]\n[/center]')"
    echo "$desc"
}

process_movie() {
    local movie_json="$1"

    local title year tmdb_id radarr_path filename quality_name
    local video_codec audio_codec audio_langs dyn_range video_depth
    local subtitles release_group overview rating genres

    title=$(echo "$movie_json" | jq -r '.title')
    year=$(echo "$movie_json" | jq -r '.year')
    tmdb_id=$(echo "$movie_json" | jq -r '.tmdbId // ""')
    radarr_path=$(echo "$movie_json" | jq -r '.movieFile.path // ""')
    radarr_path=$(map_path "$radarr_path")
    filename=$(basename "$radarr_path")
    quality_name=$(echo "$movie_json" | jq -r '.movieFile.quality.quality.name // ""')
    video_codec=$(echo "$movie_json" | jq -r '.movieFile.mediaInfo.videoCodec // ""')
    audio_codec=$(echo "$movie_json" | jq -r '.movieFile.mediaInfo.audioCodec // ""')
    audio_langs=$(echo "$movie_json" | jq -r '.movieFile.mediaInfo.audioLanguages // ""')
    dyn_range=$(echo "$movie_json" | jq -r '.movieFile.mediaInfo.videoDynamicRange // ""')
    video_depth=$(echo "$movie_json" | jq -r '.movieFile.mediaInfo.videoBitDepth // ""')
    subtitles=$(echo "$movie_json" | jq -r '.movieFile.mediaInfo.subtitles // ""')
    release_group=$(echo "$movie_json" | jq -r '.movieFile.releaseGroup // ""')
    overview=$(echo "$movie_json" | jq -r '.overview // ""')
    rating=$(echo "$movie_json" | jq -r '.ratings.tmdb.value // 0')
    genres=$(echo "$movie_json" | jq -r '[.genres[]?] | join(", ")' 2>/dev/null || echo "")
    local cover_url
    cover_url=$(echo "$movie_json" | jq -r '.images[]? | select(.coverType=="poster") | .remoteUrl // ""' 2>/dev/null | head -1)

    [ -z "$radarr_path" ] && { warn "  $title: no file path"; return 1; }
    [ ! -f "$radarr_path" ] && { warn "  $title: file not found: $radarr_path"; return 1; }

    # Exclude list check
    if is_excluded "$tmdb_id" "$title"; then
        log "  $title: excluded"; SKIPPED=$((SKIPPED+1)); return 0
    fi

    # Quality filter
    if ! meets_min_quality "$quality_name"; then
        log "  $title: below min quality ($quality_name < ${MIN_QUALITY:-})"; SKIPPED=$((SKIPPED+1)); return 0
    fi

    # Release group fallback
    if [ -z "$release_group" ] || [ "$release_group" = "null" ]; then
        release_group=$(echo "$filename" | sed 's/\.[^.]*$//' | grep -oE '\-[A-Za-z0-9]+$' | tr -d '-')
    fi

    local release_name
    release_name=$(build_release_name "$title" "$year" "$filename" \
        "$quality_name" "$video_codec" "$audio_langs" "$dyn_range" "$release_group" "$audio_codec")

    log "  $title ($year) -> $release_name"

    # Check history
    if grep -qiF "$release_name" "$HISTORY_FILE" 2>/dev/null; then
        log "  SKIP: already in history"
        SKIPPED=$((SKIPPED+1)); return 0
    fi

    # Check La Cale (cached)
    log "  Checking La Cale (TMDB:$tmdb_id)..."
    local release_count
    release_count=$(count_releases_lacale "$tmdb_id" "$title")
    log "  Found $release_count release(s) on La Cale"

    local pass_mode="${PASS_MODE:-unique}"
    if [ "$pass_mode" = "unique" ] && [ "$release_count" -gt 0 ]; then
        log "  SKIP: already on La Cale ($release_count release(s)), unique mode"
        SKIPPED=$((SKIPPED+1)); return 0
    fi

    # NFO (mediainfo output)
    local nfo_path="$WORK_DIR/${release_name}.nfo"
    mediainfo "$radarr_path" > "$nfo_path" 2>/dev/null || true
    sed -i'' "s|Complete name.*|Complete name                            : $filename|g" "$nfo_path" 2>/dev/null || true

    # Torrent
    log "  Creating torrent..."
    local torrent_path="$WORK_DIR/${release_name}.torrent"
    if ! create_torrent "$radarr_path" "$torrent_path" > /dev/null 2>&1; then
        err "  Failed to create torrent"; return 1
    fi

    # Tags
    local tag_ids
    tag_ids=$(get_tag_ids "$filename" "$quality_name" "$video_codec" \
        "$audio_codec" "$audio_langs" "$dyn_range" "$video_depth" "$subtitles")

    # Description
    local description
    description=$(_movie_description "$title" "$year" "$overview" "$genres" "$rating" "$cover_url")

    # Fresh re-check before upload
    local fresh_count
    fresh_count=$(count_releases_lacale_fresh "$tmdb_id" "$title")
    if [ "$pass_mode" = "unique" ] && [ "$fresh_count" -gt 0 ]; then
        log "  SKIP: appeared on La Cale during processing ($fresh_count release(s))"
        SKIPPED=$((SKIPPED+1)); return 0
    fi

    # Dry run stops here
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY-RUN] Would upload: $release_name"
        UPLOADED=$((UPLOADED+1)); return 0
    fi

    # Resolve category ID via active uploader
    local cat_id
    cat_id=$(uploader_resolve_category "films")
    [ -z "$cat_id" ] && { err "  Cannot resolve category ID for films (check /api/external/meta or set CAT_MOVIES)"; return 1; }

    # Upload via active uploader (internal or external)
    log "  Uploading to La Cale (${UPLOAD_METHOD:-internal})..."
    if uploader_upload "$torrent_path" "$release_name" "$cat_id" "$nfo_path" \
        "$description" "$tmdb_id" "MOVIE" "$tag_ids"; then
        log "  Upload OK"

        # Seed via provider
        log "  Adding to ${TORRENT_PROVIDER:-transmission} for seeding..."
        local save_dir
        save_dir=$(dirname "$radarr_path")
        if provider_add_torrent "$torrent_path" "$save_dir" >/dev/null 2>&1; then
            log "  Seeding OK"
        else
            warn "  Seeding failed (upload still OK)"
        fi

        echo "$release_name" >> "$HISTORY_FILE"
        UPLOADED=$((UPLOADED+1))
        notify_upload_ok "$release_name"
    else
        ERRORS=$((ERRORS+1))
        notify_upload_fail "$release_name"
        return 1
    fi
}
