#!/usr/bin/env bash
# =============================================================================
#  Bump cale-push version, commit, tag, and push.
#  Usage: ./tools/bump-version.sh <patch|minor|major>
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/cale-push"

die() { echo "error: $1" >&2; exit 1; }

# ---- Parse args ----
bump="${1:-}"
[[ "$bump" =~ ^(patch|minor|major)$ ]] || die "Usage: $0 <patch|minor|major>"

# ---- Read current version ----
current=$(sed -n 's/^LACALE_VERSION="\(.*\)"/\1/p' "$MAIN_SCRIPT")
[ -n "$current" ] || die "Could not read LACALE_VERSION from $MAIN_SCRIPT"

IFS='.' read -r major minor patch_v <<< "$current"

# ---- Bump ----
case "$bump" in
    major) major=$((major + 1)); minor=0; patch_v=0 ;;
    minor) minor=$((minor + 1)); patch_v=0 ;;
    patch) patch_v=$((patch_v + 1)) ;;
esac

new="${major}.${minor}.${patch_v}"

# ---- Update script ----
sed -i'' "s/^LACALE_VERSION=\".*\"/LACALE_VERSION=\"${new}\"/" "$MAIN_SCRIPT"

echo "${current} → ${new}"

# ---- Commit, tag, push ----
cd "$SCRIPT_DIR"
git add cale-push
git commit -m "release: v${new}"
git tag "v${new}"
git push && git push --tags

echo "Done: v${new} released"
