#!/usr/bin/env bash
# notify.sh - Notification dispatcher
#
# Loads all enabled notifiers from notifiers/ and dispatches events.
# Each notifier must implement: notifier_send(event, title, message)

NOTIFIERS_LOADED=()

# Load enabled notifiers from config
load_notifiers() {
    local notifier_dir="${LACALE_DIR}/notifiers"
    local enabled="${NOTIFY_ENABLED:-}"

    [ -z "$enabled" ] && return

    IFS=',' read -ra notifiers <<< "$enabled"
    for name in "${notifiers[@]}"; do
        name=$(echo "$name" | tr -d ' ')
        local file="${notifier_dir}/${name}.sh"
        if [ -f "$file" ]; then
            source "$file"
            if notifier_check 2>/dev/null; then
                NOTIFIERS_LOADED+=("$name")
            else
                warn "Notifier '$name' check failed, skipping"
            fi
        else
            warn "Notifier not found: $file"
        fi
    done
}

# Send a notification to all loaded notifiers
# Args:
#   $1 - event type: "upload_ok", "upload_fail", "run_summary"
#   $2 - title (short)
#   $3 - message (details)
notify() {
    local event="$1" title="$2" message="$3"

    for name in "${NOTIFIERS_LOADED[@]}"; do
        # Each notifier defines notifier_send; we source them sequentially
        # so the last sourced notifier's function is active.
        # To support multiple, we use a dispatch naming convention.
        local fn="notify_${name}"
        if declare -f "$fn" >/dev/null 2>&1; then
            "$fn" "$event" "$title" "$message" 2>/dev/null || true
        fi
    done
}

# Convenience: notify on successful upload
notify_upload_ok() {
    local release_name="$1"
    notify "upload_ok" "Upload OK" "$release_name uploaded to La Cale"
}

# Convenience: notify on failed upload
notify_upload_fail() {
    local release_name="$1" reason="${2:-upload failed}"
    notify "upload_fail" "Upload Failed" "$release_name: $reason"
}

# Convenience: notify run summary
notify_run_summary() {
    notify "run_summary" "cale-push summary" \
        "Uploaded: $UPLOADED | Skipped: $SKIPPED | Errors: $ERRORS"
}
