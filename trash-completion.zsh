#compdef ts

_trash_keys() {
    local info_dir="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/info"
    local -a keys
    for f in "$info_dir"/*.trashinfo(DN) "$info_dir"/.*.trashinfo(DN); do
        keys+=("${${f:t}%.trashinfo}")
    done
    compadd -M 'l:|=* r:|=*' -a keys
}

_ts() {
    if (( CURRENT == 2 )); then
        if [[ "$words[CURRENT]" == -* ]]; then
            local -a opts=(
                '-h[Show help]'
                '--help[Show help]'
                '-l[List trashed files]'
                '--list[List trashed files]'
                '-r[Recover files from trash]'
                '--recover[Recover files from trash]'
                '-e[Empty trash]'
                '--empty[Empty trash]'
                '-c[Manage scheduled auto-empty]'
                '--cron[Manage scheduled auto-empty]'
            )
            _describe 'option' opts
        else
            _files
        fi
        return
    fi

    case "$words[2]" in
        -l|--list)
            if (( CURRENT == 3 )); then
                compadd -- -R --Recursive -s --select
            elif (( CURRENT == 4 )); then
                case "$words[3]" in
                    -s|--select) _trash_keys ;;
                esac
            fi
            ;;
        -r|--recover)
            _trash_keys
            ;;
        -e|--empty)
            if (( CURRENT == 3 )); then
                compadd -- --older
                _trash_keys
            elif [[ "$words[3]" == "--older" ]] && (( CURRENT == 4 )); then
                return
            else
                _trash_keys
            fi
            ;;
        -c|--cron)
            if (( CURRENT == 3 )); then
                compadd -- -p --print -t --time -l --log
            elif (( CURRENT == 4 )); then
                case "$words[3]" in
                    -t|--time) ;;
                    -l|--log)
                        compadd -- --last
                        ;;
                esac
            elif (( CURRENT == 5 )); then
                case "$words[3]" in
                    -t|--time)
                        compadd -- -o --older
                        ;;
                esac
            fi
            ;;
        -*)
            ;;
        *)
            _files
            ;;
    esac
}

_ts "$@"
