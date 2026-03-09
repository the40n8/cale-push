# CLAUDE.md — Project Context

Technical context for editor tooling. Do not modify existing behavior without understanding it first.

## Project overview

**cale-push** is a Bash CLI tool that scans Radarr/Sonarr libraries and auto-uploads content to [La Cale](https://la-cale.space), a French private tracker.

## Language conventions

- **Code** (variables, functions, comments, commit messages): English
- **User-facing docs** (README, docs/, CHANGELOG): French
- **Config keys**: UPPER_SNAKE_CASE, English

## Code style

- Bash 4+ compatible, `set -euo pipefail`
- 4-space indentation, no tabs
- `local` for all function variables
- `snake_case` for functions/variables, `UPPER_CASE` for config/constants
- Keep functions short and focused — one function, one job
- No unnecessary dependencies — the tool should work with bash, curl, jq, mktorrent, mediainfo only
- shellcheck clean (see `.shellcheckrc` for project-level overrides)

## Architecture

```
cale-push          → CLI entry point, command routing
lib/core.sh        → Logging, utilities, dependency checks
lib/cache.sh       → Local cache (TSV with TTL)
lib/naming.sh      → Release name generator (La Cale naming rules)
lib/tags.sh        → Tag ID mapping for La Cale categories
lib/api.sh         → Search verification, torrent creation, slot check
lib/notify.sh      → Notification dispatcher
lib/radarr.sh      → Radarr integration
lib/sonarr.sh      → Sonarr integration
providers/*.sh     → Torrent client providers (modular)
uploaders/*.sh     → Upload method backends (modular)
notifiers/*.sh     → Notification backends (modular)
```

## Key patterns

- **Providers**: implement `provider_check()` and `provider_add_torrent(torrent_path, save_dir)`
- **Uploaders**: implement `uploader_check()`, `uploader_resolve_category(slug)`, and `uploader_upload(args...)`
- **Notifiers**: implement `notifier_check()` and `notify_<name>(event, title, message)`
- **Path mapping**: `map_path()` in core.sh translates Radarr/Sonarr paths via `PATH_MAP` config
- **Two-pass priority**: Pass 1 = unique content (not on La Cale), Pass 2 = alternative releases
- **Dry-run**: skip provider/uploader loading, torrent creation, and upload — simulate only

## Config

Config is sourced as bash. Located at `~/.config/lacale/config` or `/config/config` in Docker.
All config values have defaults set with `: "${VAR:=default}"` in `load_config()`.

## Testing

No test framework — test manually:
```bash
./cale-push check                          # Validate config + connectivity
./cale-push scan movies                    # List candidates (no upload)
./cale-push push movies --dry-run          # Simulate full pipeline
./cale-push preview "Movie.2024.1080p.BluRay.x264-GRP.mkv"  # Test naming
```

## Branching and collaboration

- **main** is the stable branch — never push directly
- Create feature branches: `feature/description` or `fix/description`
- One feature per branch, one MR/PR per feature
- Rebase on main before merging
- Tag releases: `v3.0.0`, `v3.1.0`, etc.

## Things to watch out for

- **Source flag**: `mktorrent -s "lacale"` — do NOT change this without team consensus
- **API key scope**: La Cale API requires `upload:write` scope
- **altcha PoW**: the slot check uses Python3 for SHA-256 solving — this is the only Python usage
- **No hardcoded credentials** — everything goes through config
- **Path safety**: always quote variables, especially file paths with spaces
- **Auth**: use `X-Api-Key` header (not query param) — see [API docs](https://la-cale.space/faq/api)
- **Rate limiting**: upload 30/min max. Configurable via `UPLOAD_DELAY` and `SEARCH_DELAY`
- **Category IDs**: resolved dynamically by each uploader (`/api/external/meta` or `/api/internal/categories`), fallback to `CAT_MOVIES`/`CAT_SERIES`
- **Upload method**: `UPLOAD_METHOD=internal` (session login, works now) or `external` (API key, when available)
