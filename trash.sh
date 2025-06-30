#!/bin/sh
#
# Trash Tool (freedesktop compliant, with conditional unique naming
# and collision-handled exact-match recovery and individual deletion)
#

# SET DATE in ISO8601 (required by spec)
curDate=$(date '+%Y-%m-%dT%H:%M:%S')

# COLORS
BLUE='\033[0;94m'
GREEN='\033[0;92m'
WHITE='\033[0;37m'
BOLD='\033[0;1m'
NC='\033[0m' # No Color

# XDG Trash Path (freedesktop.org spec)
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
trashDir="$XDG_DATA_HOME/Trash"
filesDir="$trashDir/files"
infoDir="$trashDir/info"

# Ensure trash directories exist
mkdir -p "$filesDir" "$infoDir"
chmod 700 "$filesDir" "$infoDir"

#########################
# Trash Action Functions#
#########################

# Move a file/folder to trash.
move_to_trash() {
    filePath="$1"
    if [ ! -e "$filePath" ]; then
        echo "$filePath: No such file or directory."
        exit 3
    fi
    fileName=$(basename "$filePath")
    originalPath=$(readlink -f "$filePath")
    trashFileName="$fileName"
    if [ -e "$filesDir/$trashFileName" ]; then
         uuid=$(date +%s%N | sha256sum | cut -c1-12)
         trashFileName="${fileName}-${uuid}"
    fi
    
    tempInfo=$(mktemp)
    cat > "$tempInfo" <<EOF
[Trash Info]
Path=$originalPath
DeletionDate=$curDate
EOF
    chmod 600 "$tempInfo"
    if mv "$tempInfo" "$infoDir/$trashFileName.trashinfo" && mv "$filePath" "$filesDir/$trashFileName"; then
         echo "Moved to trash: $trashFileName"
    else
         echo "Error: Could not move $filePath" >&2
         exit 1
    fi
}

# List trashed files by reading the .trashinfo files.
list_trash() {
    infoDir="$HOME/.local/share/Trash/info"
    delimiter="    "  # using spaces as delimiter
    longestKey=10
    longestDate=15
    longestPath=10

    for infoFile in "$infoDir"/*.trashinfo; do
        if [ -f "$infoFile" ]; then
            key=$(basename "$infoFile" .trashinfo)
            deletionDate=$(grep '^DeletionDate=' "$infoFile" | cut -d'=' -f2-)
            originalPath=$(grep '^Path=' "$infoFile" | cut -d'=' -f2-)

            if [ ${#key} -gt $longestKey ]; then
                longestKey=${#key}
            fi
            if [ ${#deletionDate} -gt $longestDate ]; then
                longestDate=${#deletionDate}
            fi
            if [ ${#originalPath} -gt $longestPath ]; then
                longestPath=${#originalPath}
            fi
        fi
    done

    # Header
    printf "${BOLD}${BLUE}%-*s${delimiter}%-*s${delimiter}%s${NC}\n" "$longestKey" "Trashed-Files" "$longestDate" "Trashed-Date" "Original-Path"

    for infoFile in "$infoDir"/*.trashinfo; do
        if [ -f "$infoFile" ]; then
            key=$(basename "$infoFile" .trashinfo)
            deletionDate=$(grep '^DeletionDate=' "$infoFile" | cut -d'=' -f2-)
            originalPath=$(grep '^Path=' "$infoFile" | cut -d'=' -f2-)

            printf "${GREEN}%-*s${delimiter}${WHITE}%-*s${delimiter}%s${NC}\n" "$longestKey" "$key" "$longestDate" "$deletionDate" "$originalPath"
        fi
    done
}

# Recover a trashed file.
recover_file() {
    searchKey="$1"
    infoFile="$infoDir/$searchKey.trashinfo"
    if [ -f "$infoFile" ]; then
         :
    else
         matches=""
         for file in "$infoDir"/*.trashinfo; do
             [ -f "$file" ] || continue
             key=$(basename "$file" .trashinfo)
             basePart=$(echo "$key" | sed 's/-.*//')
             if [ "$basePart" = "$searchKey" ]; then
                 matches="$matches $key"
             fi
         done
         set -- $matches
         if [ "$#" -eq 0 ]; then
             echo "No trashed file matching: $searchKey"
             return
         elif [ "$#" -gt 1 ]; then
             echo "Ambiguous recovery: multiple files found for base name '$searchKey':"
             for m in "$@"; do
                 echo "   $m"
             done
             echo "Please specify the exact trashed file name."
             return
         else
             infoFile="$infoDir/$1.trashinfo"
             searchKey="$1"
         fi
    fi

    originalPath=$(grep '^Path=' "$infoFile" | cut -d'=' -f2-)
    dirPath=$(dirname "$originalPath")
    baseName=$(basename "$originalPath")
    candidate="$dirPath/$searchKey"
    target=""
    
    if [ ! -e "$originalPath" ]; then
         target="$originalPath"
    elif [ ! -e "$candidate" ]; then
         target="$candidate"
    else
         uuid=$(date +%s%N | sha256sum | cut -c1-12)
         target="$dirPath/${baseName}-${uuid}"
    fi

    mkdir -p "$dirPath"
    if [ ! -e "$filesDir/$searchKey" ]; then
         echo "Trashed file not found: $searchKey"
         return
    fi
    if mv "$filesDir/$searchKey" "$target"; then
         rm -f "$infoFile"
         echo "Recovered: $target"
    else
         echo "Error: Could not recover file." >&2
         return
    fi
}

# Empty trash entirely, delete only files older than a number of days,
# or delete specific trashed file(s) if provided.
empty_trash() {
    if [ "$#" -eq 0 ]; then
         echo "Empty requires --confirm (to empty entire trash), --older [days], or one or more trashed file names."
         exit 3
    fi
    if [ "$1" = "--older" ]; then
         days="$2"
         currentTimestamp=$(date +%s)
         filesProcessed=0
         for infoFile in "$infoDir"/*.trashinfo; do
              [ -f "$infoFile" ] || continue
              deletionDate=$(grep '^DeletionDate=' "$infoFile" | cut -d'=' -f2-)
              if [ "$(uname)" = "Darwin" ]; then
                  deletionTimestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$deletionDate" "+%s" 2>/dev/null)
              else
                  formattedDeletionDate=$(echo "$deletionDate" | sed 's/T/ /')
                  deletionTimestamp=$(date -d "$formattedDeletionDate" +%s 2>/dev/null)
              fi
              if [ -z "$deletionTimestamp" ]; then
                 echo "[$curDate] Error parsing date for $(basename "$infoFile")"
                 continue
              fi
              age=$(( (currentTimestamp - deletionTimestamp) / 86400 ))
              if [ "$age" -ge "$days" ]; then
                 key=$(basename "$infoFile" .trashinfo)
                 rm -rf "$filesDir/$key" "$infoFile"
                 echo "[$curDate] Deleted: $key (older than $days days)"
                 filesProcessed=$((filesProcessed + 1))
              fi
         done
         if [ "$filesProcessed" -eq 0 ]; then
             echo "[$curDate] No files older than $days day(s) in trash."
         fi
         return
    elif [ "$1" = "--confirm" ]; then
         rm -rf "$filesDir"/* "$infoDir"/*
         echo "[$curDate] Trash emptied."
         return
    fi

    for var in "$@"; do
         if [ -f "$infoDir/$var.trashinfo" ]; then
              rm -rf "$filesDir/$var" "$infoDir/$var.trashinfo" || exit 3
              echo "Emptied:      $var"
         else
              echo "$var: No such trashed file"
              exit 3
         fi
    done
}

# Generate a cron expression
generate_cron_expression() {
  N="$1"
  cron_expr=""
  if [ "$N" -le 28 ]; then
    i="$N"
    while [ "$i" -le 28 ]; do
      cron_expr="${cron_expr}${i},"
      i=$(( i + N ))
    done
    cron_expr=$(echo "$cron_expr" | sed 's/,$//')
    echo "0 0 $cron_expr * *"
  else
    mid_day=$(( N % 30 ))
    month_interval=$(( N / 30 ))
    if [ "$mid_day" -eq 0 ]; then
        mid_day="1"
    elif [ "$mid_day" -eq 29 ]; then
       mid_day="28"
    fi
    echo "0 0 $mid_day */$month_interval *"
  fi
}

#########################
# CLI Argument Handling #
#########################

case "$1" in
    -l|--list)
         if [ "$#" -eq 1 ]; then
             list_trash
         elif [ "$#" -eq 2 ]; then
             case "$2" in
                 -R|--Recursive)
                     ls -lhaR "$filesDir"
                     ;;
                 -s|--select)
                     echo "Usage: ts -l -s folder [filter]"
                     exit 3
                     ;;
                 *)
                     list_trash | grep "$2"
                     ;;
             esac
         elif [ "$#" -eq 3 ]; then
             if [ "$2" = "-R" ] || [ "$2" = "--Recursive" ]; then
                 ls -lhaR "$filesDir" | grep "$3"
             elif [ "$2" = "-s" ] || [ "$2" = "--select" ]; then
                 key=$(ls "$infoDir"/*"${3}"*.trashinfo 2>/dev/null | head -n 1)
                 if [ -z "$key" ]; then
                    echo "No trashed folder matching: $3"
                    exit 3
                 fi
                 key=$(basename "$key" .trashinfo)
                 ls -lhaR "$filesDir/$key"
             else
                 echo "Invalid option for -l"
                 exit 3
             fi
         elif [ "$#" -eq 4 ]; then
             if [ "$2" = "-s" ] || [ "$2" = "--select" ]; then
                 key=$(ls "$infoDir"/*"${3}"*.trashinfo 2>/dev/null | head -n 1)
                 if [ -z "$key" ]; then
                    echo "No trashed folder matching: $3"
                    exit 3
                 fi
                 key=$(basename "$key" .trashinfo)
                 ls -lhaR "$filesDir/$key" | grep "$4"
             else
                 echo "Invalid option combination for -l"
                 exit 3
             fi
         else
             echo "Usage error for -l option"
             exit 3
         fi
         ;;
    -r|--recover)
         shift
         if [ "$#" -eq 0 ]; then
             echo "Recover requires an argument. Use:"
             echo "  ts -r exact_file_name   (e.g. hello.txt or hello.txt-<uniqueID>)"
             exit 3
         fi
         for fileKey in "$@"; do
             recover_file "$fileKey"
         done
         ;;
    -e|--empty)
         shift
         if [ "$#" -eq 0 ]; then
             echo "Empty requires --confirm, --older [days], or one or more trashed file names."
             exit 3
         fi
         if [ "$1" = "--older" ]; then
             empty_trash "--older" "$2"
         elif [ "$1" = "--confirm" ]; then
             empty_trash "--confirm"
         else
             empty_trash "$@"
         fi
         ;;
    -c|--cron)
         if [ "$#" -eq 2 ]; then
             case "$2" in
                 -p|--print)
                     crontab -l 2>/dev/null | grep 'trash'
                     ;;
                 *)
                     echo "Cron requires (-p | --print) or (-t | --time [days]) or (-t | --time [days] -o | --older [days])."
                     exit 1
                     ;;
             esac
         elif [ "$#" -eq 3 ] || [ "$#" -eq 5 ]; then
             case "$2" in
                 -t|--time)
                     days="$3"
                     confirmFlag="--confirm"
                     if [ "$#" -eq 5 ]; then
                         case "$4" in
                             -o|--older)
                                 confirmFlag="--older $5"
                                 ;;
                             *)
                                 echo "Invalid cron option" 
                                 exit 1
                                 ;;
                         esac
                     fi
                     if [ "$days" -eq 0 ]; then
                         crontab -l 2>/dev/null | grep -v 'trash' | crontab -
                         echo "Removed trash from crontab."
                     else
                         cronCommand="$(generate_cron_expression "$days") $(command -v trash) --empty $confirmFlag"
                         currentCron=$(crontab -l 2>/dev/null | grep 'trash' || true)
                         if [ -z "$currentCron" ]; then
                             (crontab -l 2>/dev/null; echo "$cronCommand") | crontab -
                             crontab -l 2>/dev/null | grep 'trash'
                         else
                             case "$currentCron" in
                                *"$cronCommand"*)
                                   ;;
                                *)
                                   (crontab -l | grep -v 'trash'; echo "$cronCommand") | crontab -
                                   crontab -l 2>/dev/null | grep 'trash'
                                   ;;
                             esac
                         fi
                     fi
                     ;;
                 *)
                     echo "Invalid cron option"
                     exit 1
                     ;;
             esac
         else
             echo "Cron requires (-p | --print) or (-t | --time [days]) or (-t | --time [days] -o | --older [days])."
         fi
         ;;
    -h|--help)
         echo "Trash Tool (freedesktop compliant v1.1)"
         echo ""
         echo "Usage: ts [OPTION] [FILE]"
         echo ""
         echo "Options:"
         echo "  -h, --help           Show this help menu"
         echo "  -l, --list           List trashed files"
         echo "                        [Optional: -R/--Recursive for recursive listing]"
         echo "                        [Optional: -s/--select for specific folder selection]"
         echo "                        e.g.: ts -l, ts -l filter, ts -l -R, ts -l -R filter"
         echo ""
         echo "  [no argument]        Move file(s)/folder(s) to trash"
         echo "                        e.g.: ts file1 file2 ..."
         echo ""
         echo "  -r, --recover        Recover file(s)/folder(s) from trash"
         echo "                        (Specify the exact trashed file name; if only the base name is given"
         echo "                         and multiple matches exist, the tool will print an ambiguous list.)"
         echo "                        e.g.: ts -r hello.txt   or   ts -r hello.txt-<uniqueID>"
         echo ""
         echo "  -e, --empty          Permanently delete file(s)/folder(s) from trash"
         echo "       --confirm        Empty entire trash (requires confirmation)"
         echo "       --older [days]   Delete only files older than the specified days"
         echo "       [file names]    Delete the specified trashed file(s) individually"
         echo ""
         echo "  -c, --cron           Manage automated trash emptying via cron"
         echo "       -p, --print     Show current cron job"
         echo "       -t, --time [days]   Set automatic emptying every N days"
         echo "       -o, --older [days]  Only delete files older than N days when emptying"
         exit 0
         ;;
    *)
         for file in "$@"; do
              move_to_trash "$file"
         done
         ;;
esac
