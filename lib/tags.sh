#!/usr/bin/env bash
# tags.sh - Map media info to La Cale tag IDs
# Tag IDs from /api/external/meta

get_tag_ids() {
    local filename="$1"
    local quality_name="$2"
    local video_codec="$3"
    local audio_codec="$4"
    local audio_langs="$5"
    local dyn_range="$6"
    local video_depth="$7"
    local subtitles="$8"

    local tags=""
    add_tag() { tags="${tags:+${tags},}$1"; }

    local fn_up
    fn_up=$(echo "$filename" | tr '[:lower:]' '[:upper:]')

    # Resolution
    case "$quality_name$fn_up" in
        *2160*|*4K*|*UHD*) add_tag "term_947df6343911cdf2c9e477cf4bddfc56" ;;
        *1080*)             add_tag "term_e7dd3707cd20c0cfccd272334eba5bbf" ;;
        *720*)              add_tag "term_4437c0c05981fa692427eb0d92a25a34" ;;
        *)                  add_tag "term_6ade2712b8348f39b892c00119915454" ;;
    esac

    # Video codec
    case "$video_codec$fn_up" in
        *[Xx]265*|*[Hh]265*|*HEVC*|*hevc*) add_tag "term_27dc36ee2c6fad6b87d71ed27e4b8266" ;;
        *[Xx]264*|*[Hh]264*|*AVC*|*avc*)   add_tag "term_9289368e710fa0c350a4c64f36fb03b5" ;;
        *AV1*|*av1*)                        add_tag "term_e2806600360399f7597c9d582325d1ea" ;;
    esac

    # Source
    case "$fn_up" in
        *REMUX*)   add_tag "term_fdb58f8f752de86716d0312fcfecbc71"; add_tag "term_6251bf6918d6193d846e871b8b1c2f58" ;;
        *BLURAY*|*BLU-RAY*) add_tag "term_6251bf6918d6193d846e871b8b1c2f58" ;;
        *WEB-DL*|*WEBDL*)   add_tag "term_8d7cfc3d0e1178ae2925ef270235b8d3" ;;
        *WEBRIP*)            add_tag "term_2ad87475841ea5d8111d089e5f6f2108" ;;
        *DVDRIP*)            add_tag "term_7321eb03c51abdd81902fcff4cd26171" ;;
        *HDTV*)              add_tag "term_b3cd9652a11c4bd9cdcbb7597ab8c39b" ;;
        *WEB*)               add_tag "term_8d7cfc3d0e1178ae2925ef270235b8d3" ;;
    esac

    # HDR / Dolby Vision
    case "$fn_up$dyn_range" in
        *HDR10+*|*HDR10PLUS*) add_tag "term_3458ddfaf530675b6566cf48cda76001" ;;
        *HDR*)                add_tag "term_1e6061fe0dd0f6ce8027b1bce83b6b7d" ;;
    esac
    case "$fn_up$dyn_range" in
        *DV*|*DOLBY.VISION*|*DOLBYVISION*) add_tag "term_51d58202387e82525468fc738da02246" ;;
    esac
    [ "$video_depth" = "10" ] && add_tag "term_ca34690b0fb2717154811a343bbfe05a"

    # Audio codec
    local audio_up
    audio_up=$(echo "$audio_codec" | tr '[:lower:]' '[:upper:]')
    case "$audio_up" in
        *TRUEHD*ATMOS*|*ATMOS*TRUEHD*) add_tag "term_a2cf45267addea22635047c4d69465a0" ;;
        *TRUEHD*)   add_tag "term_99a276df7596f2eb0902463e95111b76" ;;
        *EAC3*ATMOS*|*ATMOS*EAC3*)     add_tag "term_4671d371281904dcc885ddc92e92136d" ;;
        *EAC3*|*E-AC3*) add_tag "term_8945be80314068e014c773f9d4cd7eb2" ;;
        *AC3*|*DD*)  add_tag "term_e72a6bc1a89ca8c39f7a7fac21b95ef8" ;;
        *DTS:X*)     add_tag "term_b3c9a9660e1c6ab6910859254fd592e1" ;;
        *DTSHDMA*|*DTSHD*MA*) add_tag "term_49617ee39348e811452a2a4b7f5c0c64" ;;
        *DTSHD*|*DTS-HD*) add_tag "term_934dcc048eaa8b4ef48548427735a797" ;;
        *DTS*)       add_tag "term_d908f74951dee053ddada1bc0a8206db" ;;
        *AAC*)       add_tag "term_b7ce0315952660c99a4ef7099b9154cb" ;;
        *FLAC*)      add_tag "term_d857503fbf92ed967f81742146619c40" ;;
        *MP3*)       add_tag "term_0e2cdd8fd9f0031e7ffdbdb9255b8a31" ;;
    esac

    # Language tags
    if echo "$fn_up" | grep -q 'MULTI'; then
        add_tag "term_fd7d017b825ebf12ce579dacea342e9d"
        if echo "$fn_up" | grep -qE 'VFF|TRUEFRENCH'; then
            add_tag "term_bf31bb0a956b133988c2514f62eb1535"
        elif echo "$fn_up" | grep -q 'VFQ'; then
            add_tag "term_5fe7a76209bfc33e981ac5a2ca5a2e40"
        else
            add_tag "term_bf918c3858a7dfe3b44ca70232f50272"
        fi
        add_tag "term_c87b5416341e6516baac12aa01fc5bc9"
    elif echo "$fn_up" | grep -qE 'VFF|TRUEFRENCH'; then
        add_tag "term_bf31bb0a956b133988c2514f62eb1535"
    elif echo "$fn_up" | grep -q 'VFQ'; then
        add_tag "term_5fe7a76209bfc33e981ac5a2ca5a2e40"
    elif echo "$fn_up" | grep -q 'VOSTFR'; then
        add_tag "term_c87b5416341e6516baac12aa01fc5bc9"
        add_tag "term_5557a0dc2dff9923f8665c96246e2964"
    elif echo "$fn_up" | grep -q 'FRENCH'; then
        add_tag "term_bf918c3858a7dfe3b44ca70232f50272"
    else
        local lang_count
        lang_count=$(echo "$audio_langs" | tr '/' '\n' | grep -c '[a-z]' 2>/dev/null || echo 0)
        if [ "$lang_count" -gt 1 ]; then
            add_tag "term_fd7d017b825ebf12ce579dacea342e9d"
            add_tag "term_bf918c3858a7dfe3b44ca70232f50272"
            add_tag "term_c87b5416341e6516baac12aa01fc5bc9"
        elif echo "$audio_langs" | grep -qi 'french\|fra'; then
            add_tag "term_bf918c3858a7dfe3b44ca70232f50272"
        fi
    fi

    # Spoken languages
    if echo "$fn_up" | grep -q 'MULTI'; then
        add_tag "term_9cf21ecaa17940f8ea4f3b2d44627876"
        add_tag "term_de9f4583ec916d7778e08783574796a5"
    elif echo "$fn_up" | grep -qE 'FRENCH|VFF|VFQ|TRUEFRENCH'; then
        add_tag "term_9cf21ecaa17940f8ea4f3b2d44627876"
    elif echo "$fn_up" | grep -q 'VOSTFR'; then
        add_tag "term_de9f4583ec916d7778e08783574796a5"
    fi

    # Subtitles
    if [ -n "$subtitles" ]; then
        echo "$subtitles" | grep -qi 'fre\|fra\|fr\b' && add_tag "term_9ef8bba2b9cd0d6c167f97b64c216d91"
        echo "$subtitles" | grep -qi 'eng\|en\b' && add_tag "term_c0468b06760040c3a9a0674cd7eb224f"
    fi

    # Container
    local ext
    ext=$(echo "$filename" | grep -oE '\.[^.]+$' | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        .mkv) add_tag "term_513ee8e7d062c6868b092c9a4267da8a" ;;
        .mp4) add_tag "term_069f4f60531ce23f9f2bfe4ce834d660" ;;
        .avi) add_tag "term_79db12fca0a1e537f6185f7aee22b8d7" ;;
    esac

    echo "$tags"
}
