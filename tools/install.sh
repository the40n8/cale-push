#!/usr/bin/env bash
# =============================================================================
#  cale-push installer
#  Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/the40n8/cale-push/main/tools/install.sh)"
# =============================================================================
set -euo pipefail

REPO="https://github.com/the40n8/cale-push.git"
INSTALL_DIR="${CALE_PUSH_DIR:-$HOME/.cale-push}"
BIN_DIR="${CALE_PUSH_BIN:-$HOME/.local/bin}"
CONFIG_DIR="$HOME/.config/lacale"

# ---- Colors ----
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

info()  { printf "${BLUE}[info]${RESET}  %s\n" "$1"; }
ok()    { printf "${GREEN}[ok]${RESET}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[warn]${RESET}  %s\n" "$1"; }
error() { printf "${RED}[error]${RESET} %s\n" "$1" >&2; }
die()   { error "$1"; exit 1; }

# ---- Dependency check ----
check_deps() {
    local missing=()
    local optional_missing=()

    # Required
    command -v git >/dev/null 2>&1      || missing+=("git")
    command -v bash >/dev/null 2>&1     || missing+=("bash")
    command -v curl >/dev/null 2>&1     || missing+=("curl")
    command -v jq >/dev/null 2>&1       || missing+=("jq")
    command -v mktorrent >/dev/null 2>&1 || missing+=("mktorrent")
    command -v mediainfo >/dev/null 2>&1 || missing+=("mediainfo")

    # Optional
    command -v python3 >/dev/null 2>&1  || optional_missing+=("python3 (needed for altcha PoW with internal upload method)")

    # Bash version check
    if command -v bash >/dev/null 2>&1; then
        local bash_version
        bash_version="$(bash -c 'echo ${BASH_VERSINFO[0]}')"
        if [ "$bash_version" -lt 4 ]; then
            missing+=("bash 4+ (found bash $bash_version)")
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Dependencies missing:"
        for dep in "${missing[@]}"; do
            printf "  ${RED}x${RESET} %s\n" "$dep"
        done
        echo ""
        info "Install them with:"
        printf "  ${BOLD}sudo apt install %s${RESET}\n" "${missing[*]}"
        printf "  or: ${BOLD}brew install %s${RESET}\n" "${missing[*]}"
        echo ""
        die "Install the missing dependencies and re-run the installer."
    fi

    if [ ${#optional_missing[@]} -gt 0 ]; then
        for dep in "${optional_missing[@]}"; do
            warn "Optional: $dep"
        done
    fi

    ok "All dependencies found"
}

# ---- Clone / update repo ----
install_repo() {
    if [ -d "$INSTALL_DIR" ]; then
        if [ -d "$INSTALL_DIR/.git" ]; then
            info "cale-push already installed at $INSTALL_DIR, updating..."
            git -C "$INSTALL_DIR" pull --ff-only || warn "Could not update — continuing with existing version"
            ok "Updated"
        else
            die "$INSTALL_DIR exists but is not a git repo. Remove it or set CALE_PUSH_DIR to a different path."
        fi
    else
        info "Cloning cale-push to $INSTALL_DIR..."
        git clone "$REPO" "$INSTALL_DIR"
        ok "Cloned"
    fi
}

# ---- Symlink to PATH ----
setup_bin() {
    mkdir -p "$BIN_DIR"
    ln -sf "$INSTALL_DIR/cale-push" "$BIN_DIR/cale-push"
    ok "Linked cale-push to $BIN_DIR/cale-push"

    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
        warn "$BIN_DIR is not in your PATH"
        info "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        printf "  ${BOLD}export PATH=\"%s:\$PATH\"${RESET}\n" "$BIN_DIR"
    fi
}

# ---- Config ----
setup_config() {
    if [ -f "$CONFIG_DIR/config" ]; then
        ok "Config already exists at $CONFIG_DIR/config"
    else
        mkdir -p "$CONFIG_DIR"
        cp "$INSTALL_DIR/config.example" "$CONFIG_DIR/config"
        ok "Config template copied to $CONFIG_DIR/config"
        warn "Edit it with your La Cale credentials before using cale-push"
    fi
}

# ---- Bash completion ----
setup_completion() {
    if [ -f "$INSTALL_DIR/completions/cale-push.bash" ]; then
        local rc_file=""
        if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
            rc_file="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            rc_file="$HOME/.bashrc"
        fi

        if [ -n "$rc_file" ]; then
            local source_line="source \"$INSTALL_DIR/completions/cale-push.bash\""
            if ! grep -qF "$source_line" "$rc_file" 2>/dev/null; then
                info "To enable autocompletion, add this to $rc_file:"
                printf "  ${BOLD}%s${RESET}\n" "$source_line"
            fi
        fi
    fi
}

# ---- Main ----
main() {
    echo ""
    printf "${BOLD}cale-push installer${RESET}\n"
    echo ""

    check_deps
    install_repo
    setup_bin
    setup_config
    setup_completion

    echo ""
    printf "${GREEN}${BOLD}Installation complete!${RESET}\n"
    echo ""
    info "Next steps:"
    echo "  1. Edit your config:  nano ~/.config/lacale/config"
    echo "  2. Check your setup:  cale-push check"
    echo "  3. Test a scan:       cale-push scan movies"
    echo ""
}

main "$@"
