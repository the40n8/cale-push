#!/usr/bin/env bash
# notifiers/example.sh - Template for creating a custom notifier
#
# To create a notifier:
#   1. Copy this file to notifiers/yournotifier.sh
#   2. Implement notifier_check() and notify_yournotifier()
#   3. Add "yournotifier" to NOTIFY_ENABLED in your config
#
# The notifier will be sourced by the main script, so you have access
# to all config variables and lib functions (log, warn, err, die).

# Called once at startup to validate notifier config
# Return 0 if ready, 1 if not configured (will be skipped silently)
notifier_check() {
    # Check required config variables
    # [ -n "${MY_WEBHOOK:-}" ]
    return 1
}

# Send a notification
# The function name MUST be: notify_<filename_without_extension>
# Args:
#   $1 - event type: "upload_ok", "upload_fail", "run_summary"
#   $2 - title (short summary)
#   $3 - message (details)
notify_example() {
    local event="$1" title="$2" message="$3"

    # Example: send to a webhook
    # curl -sf -X POST "$MY_WEBHOOK" \
    #     -H "Content-Type: application/json" \
    #     -d "{\"event\": \"$event\", \"title\": \"$title\", \"message\": \"$message\"}" \
    #     >/dev/null 2>&1 || true

    die "Example notifier: not meant to be used directly"
}
