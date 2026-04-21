#!/bin/bash

_trash_keys() {
    local info_dir="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/info"
    for f in "$info_dir"/*.trashinfo "$info_dir"/.*.trashinfo; do
        [ -f "$f" ] || continue
        basename "$f" .trashinfo
    done
}

_trash() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        trash|ts)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "-h --help -l --list -r --recover -e --empty -c --cron" -- "$cur") )
            fi
            ;;
        -l|--list)
            COMPREPLY=( $(compgen -W "-R --Recursive -s --select" -- "$cur") )
            ;;
        -s|--select)
            COMPREPLY=( $(compgen -W "$(_trash_keys)" -- "$cur") )
            ;;
        -r|--recover)
            COMPREPLY=( $(compgen -W "$(_trash_keys)" -- "$cur") )
            ;;
        -e|--empty)
            COMPREPLY=( $(compgen -W "--older $(_trash_keys)" -- "$cur") )
            ;;
        -c|--cron)
            COMPREPLY=( $(compgen -W "-p --print -t --time" -- "$cur") )
            ;;
        -t|--time|-R|--Recursive|--older)
            return
            ;;
        *)
            local i cmd=""
            for (( i=1; i < COMP_CWORD; i++ )); do
                case "${COMP_WORDS[i]}" in
                    -r|--recover) cmd="recover"; break ;;
                    -e|--empty)   cmd="empty"; break ;;
                    -c|--cron)    cmd="cron"; break ;;
                esac
            done
            if [[ "$cmd" == "recover" || "$cmd" == "empty" ]]; then
                COMPREPLY=( $(compgen -W "$(_trash_keys)" -- "$cur") )
            elif [[ "$cmd" == "cron" ]]; then
                COMPREPLY=( $(compgen -W "-o --older" -- "$cur") )
            fi
            ;;
    esac
}

complete -o default -F _trash trash ts
