#!/usr/bin/env bash
# naming.sh - Release name builder following La Cale naming rules
#
# Films:  Titre.Annee.Info.Edition.Imax.Langue.LangueInfo.Dynamic.Resolution.Plateforme.Source.Audio.AudioChannel.AudioSpec.CodecVideo-Team
# Series: Titre.SaisonEpisode.Info.Edition.Langue.LangueInfo.Dynamic.Resolution.Plateforme.Source.Audio.AudioChannel.AudioSpec.CodecVideo-Team
#
# Rules enforced:
#   - No accents, apostrophes, cedilles
#   - First letter uppercase per word
#   - Dots as separators, hyphen only before Team
#   - No file extension in release title

_clean_title() {
    echo "$1" \
        | sed "y/àâäåéèêëïîìôöòùûüçñÀÂÄÅÉÈÊËÏÎÌÔÖÒÙÛÜÇÑ/aaaaeeeeiiiooouuucnAAAAEEEEIIIOOOUUUCN/" \
        | sed "s/[''ʼ]//g" \
        | sed "s/[\":!?,;{}()\[\]]//g" \
        | sed 's/  */ /g' \
        | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' \
        | sed 's/ /./g' \
        | sed 's/\.\././g'
}

build_release_name() {
    local title="$1" year_or_se="$2" filename="$3"
    local quality_name="$4" video_codec="$5" audio_langs="$6"
    local dyn_range="$7" release_group="$8" audio_codec="${9:-}"

    local fn_up
    fn_up=$(echo "$filename" | tr '[:lower:]' '[:upper:]')

    local title_clean
    title_clean=$(_clean_title "$title")

    # --- Info (REPACK, PROPER, CUSTOM) ---
    local info_tag=""
    case "$fn_up" in
        *REPACK2*) info_tag="REPACK2" ;;
        *REPACK*)  info_tag="REPACK" ;;
        *PROPER2*) info_tag="PROPER2" ;;
        *PROPER*)  info_tag="PROPER" ;;
        *CUSTOM*)  info_tag="CUSTOM" ;;
        *RERIP*)   info_tag="RERip" ;;
    esac

    # --- Edition (DC, EXTENDED, UNRATED, REMASTERED...) ---
    local edition_parts=()
    echo "$fn_up" | grep -qE '\.DC\.|DIRECTORS.CUT' && edition_parts+=("DC")
    echo "$fn_up" | grep -q 'EXTENDED' && edition_parts+=("EXTENDED")
    echo "$fn_up" | grep -q 'UNRATED' && edition_parts+=("UNRATED")
    echo "$fn_up" | grep -qE 'REMASTERED|REMASTER' && edition_parts+=("REMASTERED")
    echo "$fn_up" | grep -q 'RESTORED' && edition_parts+=("Restored")
    echo "$fn_up" | grep -q 'CRITERION' && edition_parts+=("CRiTERION")
    echo "$fn_up" | grep -q 'FINAL.CUT' && edition_parts+=("FiNAL.CUT")
    local edition_tag=""
    if [ ${#edition_parts[@]} -gt 0 ]; then
        edition_tag=$(IFS='.'; echo "${edition_parts[*]}")
    fi

    # --- IMAX ---
    local imax_tag=""
    echo "$fn_up" | grep -q 'IMAX' && imax_tag="iMAX"

    # --- Langue ---
    local lang_tag="FRENCH"
    if echo "$fn_up" | grep -q 'MULTI'; then
        lang_tag="MULTi"
    elif echo "$fn_up" | grep -q 'DUAL'; then lang_tag="DUAL"
    elif echo "$fn_up" | grep -qE 'TRUEFRENCH|VFF'; then lang_tag="TRUEFRENCH"
    elif echo "$fn_up" | grep -q 'VOSTFR'; then lang_tag="VOSTFR"
    elif echo "$fn_up" | grep -q 'VOF'; then lang_tag="VOF"
    elif echo "$fn_up" | grep -q 'FRENCH'; then lang_tag="FRENCH"
    else
        local lcount
        lcount=$(echo "$audio_langs" | tr '/' '\n' | grep -c '[a-z]' 2>/dev/null || echo 0)
        if [ "$lcount" -gt 1 ]; then lang_tag="MULTi"
        elif echo "$audio_langs" | grep -qi 'french\|fra'; then lang_tag="FRENCH"
        fi
    fi

    # --- LangueInfo (VFF, VFQ, VF2, AD) ---
    local lang_info=""
    if [ "$lang_tag" = "MULTi" ]; then
        if echo "$fn_up" | grep -qE 'VFF|TRUEFRENCH'; then lang_info="VFF"
        elif echo "$fn_up" | grep -q 'VFQ'; then lang_info="VFQ"
        elif echo "$fn_up" | grep -q 'VF2'; then lang_info="VF2"
        elif echo "$fn_up" | grep -q 'VFI'; then lang_info="VFi"
        fi
    fi
    if echo "$fn_up" | grep -qE '\.AD\.|\.AD$'; then
        [ -n "$lang_info" ] && lang_info="${lang_info}.AD" || lang_info="AD"
    fi

    # --- Dynamic (HDR, DV) ---
    local hdr_tag=""
    case "$fn_up$dyn_range" in
        *HDR10+*|*HDR10PLUS*) hdr_tag="HDR10+" ;;
        *HDR*) hdr_tag="HDR" ;;
    esac
    if echo "$fn_up$dyn_range" | grep -qi 'DV\|DOLBY.VISION'; then
        [ -n "$hdr_tag" ] && hdr_tag="${hdr_tag}.DV" || hdr_tag="DV"
    fi

    # --- Resolution ---
    local resolution=""
    case "$quality_name$fn_up" in
        *2160*|*4K*|*UHD*) resolution="2160p" ;;
        *1080*)            resolution="1080p" ;;
        *720*)             resolution="720p" ;;
    esac

    # --- Plateforme ---
    local platform=""
    case "$fn_up" in
        *\.NF\.*|*\.NETFLIX\.*)  platform="NF" ;;
        *\.AMZN\.*|*\.AMAZON\.*) platform="AMZN" ;;
        *\.DSNP\.*|*\.DISNEY\.*) platform="DSNP" ;;
        *\.ATVP\.*)              platform="ATVP" ;;
        *\.HMAX\.*|*\.MAX\.*)    platform="MAX" ;;
        *\.PMTP\.*)              platform="PMTP" ;;
        *\.HULU\.*)              platform="HULU" ;;
        *\.CR\.*)                platform="CR" ;;
        *\.PCOK\.*)              platform="PCOK" ;;
        *\.ADN\.*)               platform="ADN" ;;
    esac

    # --- Source ---
    local source="WEB"
    case "$fn_up" in
        *COMPLETE*UHD*BLU*)     source="COMPLETE.UHD.BLURAY" ;;
        *COMPLETE*BLU*)         source="COMPLETE.BLURAY" ;;
        *BLU*REMUX*|*BD*REMUX*) source="BluRay.REMUX" ;;
        *DVD*REMUX*)            source="DVD.REMUX" ;;
        *REMUX*)                source="REMUX" ;;
        *4KLIGHT*)              source="4KLight" ;;
        *HDLIGHT*)              source="HDLight" ;;
        *MHD*)                  source="mHD" ;;
        *BLURAY*|*BLU-RAY*|*BDRIP*) source="BluRay" ;;
        *WEB-DL*|*WEBDL*)      source="WEB-DL" ;;
        *WEBRIP*)               source="WEBRip" ;;
        *DVDRIP*)               source="DVDRip" ;;
        *HDTV*)                 source="HDTV" ;;
        *WEB*)                  source="WEB" ;;
    esac

    # --- Audio ---
    local audio_tag=""
    if [ -n "$audio_codec" ] && [ "$audio_codec" != "null" ]; then
        local ac_up
        ac_up=$(echo "$audio_codec" | tr '[:lower:]' '[:upper:]')
        case "$ac_up" in
            *TRUEHD*)              audio_tag="TrueHD" ;;
            *EAC3*|*E-AC3*|*DDP*) audio_tag="EAC3" ;;
            *AC3*|*DD*)            audio_tag="AC3" ;;
            *DTS:X*|*DTSX*)        audio_tag="DTS-X" ;;
            *DTS-HD*MA*|*DTSHDMA*) audio_tag="DTS-HD.MA" ;;
            *DTS-HD*|*DTSHD*)      audio_tag="DTS-HD" ;;
            *DTS*)                 audio_tag="DTS" ;;
            *AAC*)                 audio_tag="AAC" ;;
            *FLAC*)                audio_tag="FLAC" ;;
            *OPUS*)                audio_tag="OPUS" ;;
            *MP3*)                 audio_tag="MP3" ;;
        esac
    fi

    # --- AudioChannel ---
    local audio_channel=""
    if echo "$fn_up" | grep -qE '7\.1'; then audio_channel="7.1"
    elif echo "$fn_up" | grep -qE '5\.1'; then audio_channel="5.1"
    elif echo "$fn_up" | grep -qE '2\.0'; then audio_channel="2.0"
    elif echo "$fn_up" | grep -qE '1\.0'; then audio_channel="1.0"
    fi

    # --- AudioSpec ---
    local audio_spec=""
    echo "$fn_up" | grep -q 'ATMOS' && audio_spec="Atmos"

    # --- CodecVideo ---
    local codec="x264"
    case "$fn_up$video_codec" in
        *[Xx]265*|*[Hh]265*|*HEVC*|*hevc*) codec="x265" ;;
        *[Xx]264*|*[Hh]264*|*AVC*|*avc*)   codec="x264" ;;
        *AV1*|*av1*)                        codec="AV1" ;;
        *MPEG2*|*MPEG*)                     codec="MPEG" ;;
        *VC-1*|*VC1*)                       codec="VC-1" ;;
    esac

    # --- Team ---
    local team="${release_group}"
    if [ -z "$team" ] || [ "$team" = "null" ]; then
        team="NOGRP"
    fi

    # --- Assemble ---
    local name="${title_clean}.${year_or_se}"
    [ -n "$info_tag" ] && name="${name}.${info_tag}"
    [ -n "$edition_tag" ] && name="${name}.${edition_tag}"
    [ -n "$imax_tag" ] && name="${name}.${imax_tag}"
    name="${name}.${lang_tag}"
    [ -n "$lang_info" ] && name="${name}.${lang_info}"
    [ -n "$hdr_tag" ] && name="${name}.${hdr_tag}"
    [ -n "$resolution" ] && name="${name}.${resolution}"
    [ -n "$platform" ] && name="${name}.${platform}"
    name="${name}.${source}"
    [ -n "$audio_tag" ] && name="${name}.${audio_tag}"
    [ -n "$audio_channel" ] && name="${name}.${audio_channel}"
    [ -n "$audio_spec" ] && name="${name}.${audio_spec}"
    name="${name}.${codec}-${team}"

    echo "$name"
}
