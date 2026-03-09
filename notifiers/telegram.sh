#!/usr/bin/env bash
# notifiers/telegram.sh - Telegram bot notifications
#
# Required config:
#   TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
#   TELEGRAM_CHAT_ID="-1001234567890"

notifier_check() {
    [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]
}

notify_telegram() {
    local event="$1" title="$2" message="$3"

    local icon
    case "$event" in
        upload_ok)   icon="✅" ;;
        upload_fail) icon="❌" ;;
        run_summary) icon="📊" ;;
        *)           icon="ℹ️" ;;
    esac

    local text="${icon} *${title}*
${message}"

    curl -sf -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${text}" \
        -d "parse_mode=Markdown" >/dev/null 2>&1 || true
}
