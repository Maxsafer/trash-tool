#!/bin/bash
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
# Use the original name unless a file with that name already exists;
# if so, append a unique identifier.
move_to_trash() {
    local filePath="$1"
    if [ ! -e "$filePath" ]; then
        echo "$filePath: No such file or directory." && exit 3
    fi
    local fileName
    fileName=$(basename -- "$filePath")
    local originalPath
    originalPath=$(readlink -f "$filePath")
    local trashFileName="$fileName"
    if [ -e "$filesDir/$trashFileName" ]; then
         local uuid
         uuid=$(date +%s%N | sha256sum | cut -c1-12)
         trashFileName="${fileName}-${uuid}"
    fi

    mv "$filePath" "$filesDir/$trashFileName" || { echo "Error: Could not move $filePath"; exit 1; }

    # Create the .trashinfo metadata file (per freedesktop spec)
    cat > "$infoDir/$trashFileName.trashinfo" <<EOF
[Trash Info]
Path=$originalPath
DeletionDate=$curDate
EOF
chmod 600 "$infoDir/$trashFileName.trashinfo"

    echo "Moved to trash: $trashFileName"
}

# List trashed files by reading the .trashinfo files.
list_trash() {
    echo -e "${BOLD}${BLUE}Trashed Files:${NC}"
    for infoFile in "$infoDir"/*.trashinfo; do
        if [[ -f "$infoFile" ]]; then
            local key
            key=$(basename -- "$infoFile" .trashinfo)
            local deletionDate
            deletionDate=$(grep '^DeletionDate=' "$infoFile" | cut -d'=' -f2-)
            local originalPath
            originalPath=$(grep '^Path=' "$infoFile" | cut -d'=' -f2-)
            printf "${GREEN}%-40s${WHITE} %-25s %s${NC}\n" "$key" "$deletionDate" "$originalPath"
        fi
    done
}

# Recover a trashed file.
# Look for an exact match using the provided key.
# If none is found, search among trashed files whose base name (before a hyphen)
# matches the provided key. If multiple are found, print an error.
recover_file() {
    local searchKey="$1"
    local infoFile="$infoDir/$searchKey.trashinfo"
    if [ -f "$infoFile" ]; then
         # Exact match found.
         :
    else
         local matches=()
         for file in "$infoDir"/*.trashinfo; do
             [ -f "$file" ] || continue
             local key
             key=$(basename "$file" .trashinfo)
             local basePart="${key%%-*}"
             if [ "$basePart" == "$searchKey" ]; then
                 matches+=("$key")
             fi
         done
         if [ ${#matches[@]} -eq 0 ]; then
             echo "No trashed file matching: $searchKey"
             return
         elif [ ${#matches[@]} -gt 1 ]; then
             echo "Ambiguous recovery: multiple files found for base name '$searchKey':"
             for m in "${matches[@]}"; do
                 echo "   $m"
             done
             echo "Please specify the exact trashed file name."
             return
         else
             infoFile="$infoDir/${matches[0]}.trashinfo"
             searchKey="${matches[0]}"
         fi
    fi

    # Read original path from .trashinfo
    local originalPath
    originalPath=$(grep '^Path=' "$infoFile" | cut -d'=' -f2-)
    local dirPath
    dirPath=$(dirname "$originalPath")
    local baseName
    baseName=$(basename "$originalPath")
    local candidate="$dirPath/$searchKey"
    local target=""
    
    # Collision handling:
    if [ ! -e "$originalPath" ]; then
         target="$originalPath"
    elif [ ! -e "$candidate" ]; then
         target="$candidate"
    else
         local uuid
         uuid=$(date +%s%N | sha256sum | cut -c1-12)
         target="$dirPath/${baseName}-${uuid}"
    fi

    mkdir -p "$dirPath"
    if [ ! -e "$filesDir/$searchKey" ]; then
         echo "Trashed file not found: $searchKey"
         return
    fi
    mv "$filesDir/$searchKey" "$target" || { echo "Error: Could not recover file."; return; }
    rm -f "$infoFile"
    echo "Recovered: $target"
}

# Empty trash entirely, delete only files older than a number of days,
# or delete specific trashed file(s) if provided.
empty_trash() {
    # If no arguments are provided, error.
    if [ $# -eq 0 ]; then
         echo "Empty requires --confirm (to empty entire trash), --older [days], or one or more trashed file names."
         exit 3
    fi
    # If the first argument is --older or --confirm, handle accordingly.
    if [ "$1" == "--older" ]; then
         local days="$2"
         local currentTimestamp
         currentTimestamp=$(date +%s)
         local filesProcessed=0
         for infoFile in "$infoDir"/*.trashinfo; do
              [ -f "$infoFile" ] || continue
              local deletionDate
              deletionDate=$(grep '^DeletionDate=' "$infoFile" | cut -d'=' -f2-)
              
              # Use OS detection to parse the ISO date properly.
              local deletionTimestamp
              if [ "$(uname)" = "Darwin" ]; then
                  deletionTimestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$deletionDate" "+%s" 2>/dev/null)
              else
                  # Replace 'T' with space for Linux date
                  local formattedDeletionDate="${deletionDate/T/ }"
                  deletionTimestamp=$(date -d "$formattedDeletionDate" +%s 2>/dev/null)
              fi
              if [ -z "$deletionTimestamp" ]; then
                 echo "Error parsing date for $(basename "$infoFile")"
                 continue
              fi
              local age=$(( (currentTimestamp - deletionTimestamp) / 86400 ))
              if (( age >= days )); then
                 local key
                 key=$(basename "$infoFile" .trashinfo)
                 rm -rf "$filesDir/$key" "$infoFile"
                 echo "Deleted: $key (older than $days days)"
                 filesProcessed=$((filesProcessed+1))
              fi
         done
         if [ $filesProcessed -eq 0 ]; then
             echo "No files older than $days day(s) in trash."
         fi
         return
    elif [ "$1" == "--confirm" ]; then
         rm -rf "$filesDir"/* "$infoDir"/*
         echo "Trash emptied."
         return
    fi

    # Otherwise, treat each argument as a specific trashed file to delete.
    for var in "$@"; do
         if [ -f "$infoDir/$var.trashinfo" ]; then
              rm -rf "$filesDir/$var" "$infoDir/$var.trashinfo" || exit 3
              echo "Emptied:      $var"
         else
              echo "$var: No such trashed file" && exit 3
         fi
    done
}

# Generate a cron expression
generate_cron_expression() {
  local N=$1
  local cron_expr=""
  if (( N <= 28 )); then
    for (( i = N; i <= 28; i+=N )); do
      cron_expr+="$i,"
    done
    cron_expr=${cron_expr%,}
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

#########################
# CLI Argument Handling #
#########################

case "$1" in
    "-l" | "--list")
         # Options for listing:
         if [ $# -eq 1 ]; then
             list_trash
         elif [ $# -eq 2 ]; then
             case "$2" in
                 "-R" | "--Recursive")
                     ls -lhaR "$filesDir"
                     ;;
                 "-s" | "--select")
                     echo "Usage: ts -l -s folder [filter]"
                     exit 3
                     ;;
                 *)
                     list_trash | grep "$2"
                     ;;
             esac
         elif [ $# -eq 3 ]; then
             if [ "$2" == "-R" ] || [ "$2" == "--Recursive" ]; then
                 ls -lhaR "$filesDir" | grep "$3"
             elif [ "$2" == "-s" ] || [ "$2" == "--select" ]; then
                 key=$(ls "$infoDir"/*"${3}"*.trashinfo 2>/dev/null | head -n1)
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
         elif [ $# -eq 4 ]; then
             if [ "$2" == "-s" ] || [ "$2" == "--select" ]; then
                 key=$(ls "$infoDir"/*"${3}"*.trashinfo 2>/dev/null | head -n1)
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
    "-r" | "--recover")
         shift
         if [ $# -eq 0 ]; then
             echo "Recover requires an argument. Use:"
             echo "  ts -r exact_file_name   (the exact trashed file name, e.g. hello.txt or hello.txt-<uniqueID>)"
             exit 3
         fi
         for fileKey in "$@"; do
             recover_file "$fileKey"
         done
         ;;
    "-e" | "--empty")
         shift
         if [ $# -eq 0 ]; then
             echo "Empty requires --confirm, --older [days], or one or more trashed file names."
             exit 3
         fi
         if [ "$1" == "--older" ]; then
             empty_trash "--older" "$2"
         elif [ "$1" == "--confirm" ]; then
             empty_trash "--confirm"
         else
             empty_trash "$@"
         fi
         ;;
    "-c" | "--cron")
         if [ $# -eq 2 ] && { [ "$2" == "-p" ] || [ "$2" == "--print" ]; }; then
              echo "$(crontab -l 2>/dev/null | grep 'trash')"
         elif { [ $# -eq 3 ] || [ $# -eq 5 ]; } && { [ "$2" == "-t" ] || [ "$2" == "--time" ]; }; then
              days=$3
              confirmFlag="--confirm"
              if [ $# -eq 5 ] && { [ "$4" == "-o" ] || [ "$4" == "--older" ]; }; then
                    confirmFlag="--older $5"
              fi
              if [ "$days" -eq 0 ]; then
                   crontab -l 2>/dev/null | grep -v 'trash' | crontab -
                   echo "Removed trash from crontab."
              else
                   cronCommand="$(generate_cron_expression "$days") $0 --empty $confirmFlag"
                   currentCron=$(crontab -l 2>/dev/null | grep 'trash')
                   if [ -z "$currentCron" ]; then
                        (crontab -l 2>/dev/null; echo "$cronCommand") | crontab -
                        echo "$(crontab -l 2>/dev/null | grep 'trash')"
                   elif [[ "$currentCron" != *"$cronCommand"* ]]; then
                        (crontab -l | grep -v 'trash'; echo "$cronCommand") | crontab -
                        echo "$(crontab -l 2>/dev/null | grep 'trash')"
                   fi
              fi
         else
              echo "Cron requires (-p | --print) or (-t | --time [days]) or (-t | --time [days] -o | --older [days])."
         fi
         ;;
    "-h" | "--help")
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
         exit
         ;;
    *)
         # Default: move each specified file/folder to trash.
         for file in "$@"; do
              move_to_trash "$file"
         done
         ;;
esac
