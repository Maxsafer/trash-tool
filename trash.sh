#!/bin/bash

# SET DATE
curDate=$(date '+%Y-%m-%d_%H-%M-%S')

# COLORS
BLUE='\033[0;94m'
GREEN='\033[0;92m'
WHITE='\033[0;37m'
BOLD='\033[0;1m'
NC='\033[0m' # No Color

# el path de trash_tool
toolDir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

# logica de lo primero que haga ver que su ruta de trash_can existe y si no, crearla
if [ ! -d "$toolDir/trash_can" ]; then
    mkdir "$toolDir/trash_can"
    chmod 700 "$toolDir/trash_can"
fi

# logica de json presente
if [ ! -f "$toolDir/trash.json" ]; then
    touch "$toolDir/trash.json"
    chmod 700 "$toolDir/trash.json"
    echo '{"fileName":["filePath","trashDate"]}' >> "$toolDir/trash.json"
fi

# funcion para crear la expresion cron
generate_cron_expression() {
  local N=$1
  local cron_expr=""

  if (( N <= 28 )); then
    for (( i = N; i <= 28; i+=N )); do
      cron_expr+="$i,"
    done
    cron_expr=${cron_expr%,}  # Remove trailing comma
    echo "0 0 $cron_expr * *"
  
  else
    local mid_day=$(( N % 30 ))
    local month_interval=$((N / 30))
    if [ "$mid_day" == "0" ]; then
        mid_day="1"
    elif [ "$mid_day" == "29" ]; then
       mid_day="28" 
    fi
    echo "0 0 $mid_day */$month_interval *"
  fi
}

# logica de cron
if [ "$1" == "-c" ] || [ "$1" == "--cron" ]; then
    if [ $# == 2 ] && ([ "$2" == "-p" ] || [ "$2" == "--print" ]); then
        echo "$(crontab -l 2>/dev/null | grep 'trash')"
    elif ([ $# == 3 ] || [ $# == 5 ])  && ([ "$2" == "-t" ] || [ "$2" == "--time" ]); then
        # agregar logica para cundo si trae un older than para solo borra files viejos
        days=$3
        olderThan="--confirm"
        if [ $# == 5 ] && ([ "$4" == "-o" ] || [ "$4" == "--older" ]); then
            olderThan="--older $5"
        fi
        # If days is 0, remove any existing cron job for this process
        if [[ "$days" -eq 0 ]]; then
            crontab -l 2>/dev/null | grep -v 'trash' | crontab -
            echo "Removed trash from crontab."
        else
            cronCommand="$(generate_cron_expression "$days") $toolDir/trash.sh --empty $olderThan"

            # Check existing cron job
            currentCron=$(crontab -l 2>/dev/null | grep 'trash')
            
            # Update crontab if necessary
            if [[ -z "$currentCron" ]]; then
                (crontab -l 2>/dev/null; echo "$cronCommand") | crontab -
                echo "$(crontab -l 2>/dev/null | grep 'trash')"
            elif [[ "$currentCron" != *"$cronCommand"* ]]; then
                (crontab -l | grep -v 'trash'; echo "$cronCommand") | crontab - 
                echo "$(crontab -l 2>/dev/null | grep 'trash')"
            fi
        fi
    else
        echo "Cron requires the following arguments (-p | --print) or (-t | --time [day interval]) or (-t | --time [day interval] -o | --older [days])."
    fi
    exit
fi

# logica de mostrar files en trash
if [ "$1" == "-l" ] || [ "$1" == "--list" ]; then
    # ONE ARGUMENT
    if [ $# == 1 ]; then
        ls -lha "$toolDir/trash_can"
    # TWO ARGUMENTS
    elif [ $# == 2 ] && ([ "$2" == "-R" ] || [ "$2" == "--Recursive" ]); then
        ls -lhaR "$toolDir/trash_can"
    elif [ $# == 2 ] && ([ "$2" != "-s" ] && [ "$2" != "--select" ]); then
        cd "$toolDir/trash_can/"
        ls -lha | grep $2
    # THREE ARGUMENTS
    elif [ $# == 3 ]  && ([ "$2" == "-s" ] || [ "$2" == "--select" ]); then
        ls -lhaR "$toolDir/trash_can/$3"
    elif [ $# == 3 ] && ([ "$2" == "-R" ] || [ "$2" == "--Recursive" ]); then
        ls -lhaR "$toolDir/trash_can"| grep $3
    # FOUR ARGUMENTS
    elif [ $# == 4 ]  && ([ "$2" == "-s" ] || [ "$2" == "--select" ]); then
        ls -lhaR "$toolDir/trash_can/$3" | grep $4
    # ELSE
    else
        echo "Please use trash -h in order to learn how to use trash."
    fi
    exit
fi

# logica de recover files en trash
if [ "$1" == "-r" ] || [ "$1" == "--recover" ]; then
    if [ $# == 2 ]  && ([ "$2" == "-d" ] || [ "$2" == "--dictionary" ]); then
        "$toolDir/trash_parser.sh" "$toolDir/trash.json" "--list-all"
    elif [ $# == 3 ]  && ([ "$2" == "-d" ] || [ "$2" == "--dictionary" ]); then
        # Header with fixed width
        printf "${BOLD}${BLUE}%-30s %-25s %-s${NC}\n" "grep '$3'" "trashDate" "filePath"
        printf "${WHITE}%.0s-" {1..80}  # Prints 80 dashes
        printf "\n"
        FORCE_PRETTY=1 "$toolDir/trash_parser.sh" "$toolDir/trash.json" "--list-all" | grep $3
    else
        for var in "$@"; do
            if [ "$var" != "-r" ] && [ "$var" != "--recover" ] && [ "$var" != "fileName" ]; then
                recover=$("$toolDir/trash_parser.sh" "$toolDir/trash.json" "--remove" "$var")
                if [ "$recover" == "None" ]; then
                    echo "$var : No such file or directory" && exit 3
                fi
                mkdir -p "${recover%/*}/" && mv "$toolDir/trash_can/$var" "$recover" || exit 3
                echo "recovered:      $var     to      $recover"
            fi
        done
    fi
    exit
fi

# logica de borrar files en trash
if [ "$1" == "-e" ] || [ "$1" == "--empty" ]; then
    if [ "$2" == "--confirm" ]; then
        if [ "$(ls -A $toolDir/trash_can/)" ]; then
            cd "$toolDir/trash_can/"
            rm -Rf * || exit 3
            rm "$toolDir/trash.json"
            echo " trash can"
        else
            echo "trash is already empty"
        fi

    elif [ "$2" == "--older" ]; then
        days_old=$3
        files_processed=0
        # Process each entry
        while IFS="|" read -r key date path; do
            # Convert dates to timestamps for comparison (macOS compatible)
            item_timestamp=$(date -j -f "%Y-%m-%d_%H-%M-%S" "$date" "+%s")
            current_timestamp=$(date -j -f "%Y-%m-%d_%H-%M-%S" "$curDate" "+%s")
            age_days=$(( (current_timestamp - item_timestamp) / 86400 ))
            
            if [ "$age_days" -ge "$days_old" ]; then
                # Remove from JSON
                delete=$("$toolDir/trash_parser.sh" "$toolDir/trash.json" "--remove" "$key")
                if [ "$delete" == "None" ]; then
                    echo "$var : No such file or directory." && exit 3
                fi
                # Remove from trash directory
                cd "$toolDir/trash_can/"
                rm -Rf "$key" || exit 3
                echo ":      $key ($path) is older than $days_old days."
                files_processed=$((files_processed + 1))
            fi
        done < <("$toolDir/trash_parser.sh" "$toolDir/trash.json" --list-all)
        if [ $files_processed -eq 0 ]; then
            echo "No trash older than $days_old day(s)."
        fi
    else
        for var in "$@"; do
            cd "$toolDir"
            if [ "$var" != "-e" ] && [ "$var" != "--empty" ] && [ "$var" != "fileName" ]; then
                delete=$("$toolDir/trash_parser.sh" "$toolDir/trash.json" "--remove" "$var")
                if [ "$delete" == "None" ]; then
                    echo "$var : No such file or directory." && exit 3
                fi
                cd "$toolDir/trash_can/"
                rm -Rf "$var" || exit 3
                echo "emptied:      $var"
            fi
        done
    fi
    exit
fi

# logica de help
if [ $# == 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Trash Tool v1.1"
    echo " "
    echo "Usage: trash [OPTION] SOURCE"
    echo "Usage: ts [OPTION] SOURCE"
    echo " "
    echo "Tool documentation: https://github.com/Maxsafer/trash-tool"
    echo " "
    echo "Argument list:"
    echo "-h, --help            Display this help menu."
    echo "-l, --list            List files inside the trash can."
    echo "                      [Optional: Can include a text/regex filter]"
    echo "                          e.g.    trash -l [text/regex]"
    echo "   -R, --Recursive    Recursively list all items in the trash can."
    echo "                      [Optional: Can include a text/regex filter]"
    echo "                          e.g.    trash -l -R [text/regex]"
    echo "   -s, --select       List a specific trashed file/folder recursively."
    echo "                      [Optional: Can include a text/regex filter]"
    echo "                          e.g.    trash -l -s folder [text/regex]"
    echo " "
    echo "[no argument]         Move file(s)/folder(s) to the trash."
    echo "                          e.g.    trash file1 file2 ..."
    echo " "
    echo "-r, --recover         Recover file(s)/folder(s) from the trash."
    echo "                          e.g.    trash -r file1 file2 ..."
    echo "   -d, --dictionary   Display the dictionary of trashed files."
    echo "                      [Optional: Can include a text/regex filter]"
    echo "                          e.g.    trash -r -d [text/regex]"
    echo " "
    echo "-e, --empty           Permanently delete file(s)/folder(s) from the trash."
    echo "                          e.g.    trash -e file1 file2 ..."
    echo "   --confirm          Empty the entire trash can."
    echo "                          e.g.    trash -e --confirm"
    echo "   --older [days]     Delete only files older than the specified days."
    echo "                          e.g.    trash -e --older 30"
    echo " "
    echo "-c, --cron            Manage automated trash emptying via cron."
    echo "   -p, --print        Display the current cron job related to trash."
    echo "                          e.g.    trash -c -p"
    echo "   -t, --time [days]  Set up automatic emptying of trash every N days."
    echo "                          e.g.    trash -c -t 7"
    echo "   -o, --older [days] Only delete files older than N days when emptying."
    echo "                          e.g.    trash -c -t 7 -o 30"
    echo " "
    exit
elif [[ "$1" =~ ^"-" ]] || [[ "$1" =~ ^"--" ]]; then
    echo "Unknown argument, for help please use: trash -h"
    exit 3
fi

# logica de trash file/folder
if [ $# == 1 ]; then
    if [ "$1" == "fileName" ]; then
        echo "[Error] Reserved trash name: 'fileName'." && exit 3
    fi
    file=$(basename -- "$1")
    prevJson=$(echo $(cat "$toolDir/trash.json") | sed 's/.$//')
    fileDir=$(readlink -f "$1")
    if [ ! -f "$fileDir" ] && [ ! -d "$fileDir" ]; then
        echo "$1" : No such file or directory. && exit 3
    elif [ -f "$toolDir/trash_can/$file" ] || [ -d "$toolDir/trash_can/$file" ]; then
        mv "$1" "$toolDir/trash_can/$curDate-$file" || exit 3
        echo "$prevJson,"$'\n'\"$curDate-$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
    else
        mv "$1" "$toolDir/trash_can"
        echo "$prevJson,"$'\n'\"$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
    fi

# logica de trash multiple files
else
    for x in "$@"; do
        file=$(basename -- "$x")
        prevJson=$(echo $(cat "$toolDir/trash.json") | sed 's/.$//')
        fileDir=$(readlink -f "$x")
        if [ ! -f "$fileDir" ] && [ ! -d "$fileDir" ]; then
            echo "$x" : No such file or directory. && exit 3
        elif [ -f "$toolDir/trash_can/$file" ] || [ -d "$toolDir/trash_can/$file" ]; then
            mv "$x" "$toolDir/trash_can/$curDate-$file" || exit 3
            echo "$prevJson,"$'\n'\"$curDate-$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
        else
            mv "$x" "$toolDir/trash_can" || exit 3
            echo "$prevJson,"$'\n'\"$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
        fi
    done
fi
