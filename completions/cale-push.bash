#!/usr/bin/env bash
# Bash completion for cale-push
# Source this file or copy to /etc/bash_completion.d/cale-push
#
# Setup:
#   echo 'source /path/to/cale-push/completions/cale-push.bash' >> ~/.bashrc

_cale_push() {
    local cur prev commands modes
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="push scan search preview check install uninstall update status version help"
    modes="movies series all"

    # First argument: command
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return
    fi

    local cmd="${COMP_WORDS[1]}"

    case "$cmd" in
        push)
            case "$prev" in
                push)
                    COMPREPLY=( $(compgen -W "$modes --max --dry-run --min-quality --config=" -- "$cur") )
                    ;;
                --max)
                    COMPREPLY=( $(compgen -W "1 3 5 10 20" -- "$cur") )
                    ;;
                --min-quality)
                    COMPREPLY=( $(compgen -W "480p 720p 1080p 2160p" -- "$cur") )
                    ;;
                movies|series|all)
                    COMPREPLY=( $(compgen -W "--max --dry-run --min-quality" -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "--max --dry-run --min-quality" -- "$cur") )
                    ;;
            esac
            ;;
        scan|install)
            COMPREPLY=( $(compgen -W "$modes" -- "$cur") )
            ;;
        search)
            # No completion for search queries
            ;;
        preview)
            # Complete file paths
            COMPREPLY=( $(compgen -f -- "$cur") )
            ;;
    esac
}

complete -F _cale_push cale-push
complete -F _cale_push ./cale-push
