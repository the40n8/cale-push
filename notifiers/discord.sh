#!/usr/bin/env bash
# notifiers/discord.sh - Discord webhook notifications
#
# Required config:
#   DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."

notifier_check() {
    [ -n "${DISCORD_WEBHOOK_URL:-}" ]
}

notify_discord() {
    local event="$1" title="$2" message="$3"

    local color
    case "$event" in
        upload_ok)   color=5763719  ;;  # green
        upload_fail) color=15548997 ;;  # red
        run_summary) color=5793266  ;;  # blue
        *)           color=9807270  ;;  # grey
    esac

    local payload
    payload=$(jq -nc \
        --arg title "$title" \
        --arg desc "$message" \
        --argjson color "$color" \
        '{embeds: [{title: $title, description: $desc, color: $color, footer: {text: "cale-push"}}]}')

    curl -sf -H "Content-Type: application/json" \
        -d "$payload" \
        "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
}
