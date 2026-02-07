#!/bin/bash
# Bash completion for dedupctl (Borg backup) script

_dedupctl() {
    local cur prev subcommands opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # List of available subcommands
    subcommands="init backup prune mount extract check log list diff size"

    # If completing the first argument, simply complete subcommands.
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
        return 0
    fi

    # Provide extra options for certain subcommands:
    case "${COMP_WORDS[1]}" in
        init|backup)
            opts="--dry-run --force-full --create"
            ;;
        prune)
            opts="--last --first --older --newer --all"
            ;;
        *)
            opts=""
            ;;
    esac

    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return 0
}

complete -F _dedupctl dedupctl
