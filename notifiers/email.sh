#!/usr/bin/env bash
# notifiers/email.sh - Email notifications via sendmail/mail command
#
# Required config:
#   NOTIFY_EMAIL_TO="you@example.com"
# Optional:
#   NOTIFY_EMAIL_FROM="cale-push@localhost"

notifier_check() {
    [ -n "${NOTIFY_EMAIL_TO:-}" ] && command -v mail >/dev/null 2>&1
}

notify_email() {
    local event="$1" title="$2" message="$3"
    local from="${NOTIFY_EMAIL_FROM:-cale-push@localhost}"

    printf "Subject: [cale-push] %s\nFrom: %s\nTo: %s\n\n%s\n" \
        "$title" "$from" "$NOTIFY_EMAIL_TO" "$message" | \
        mail -s "[cale-push] $title" "$NOTIFY_EMAIL_TO" 2>/dev/null || true
}
