#!/bin/bash

#SET DATE
curDate=$(date '+%Y-%m-%d_%H-%M-%S')

# logica de lo primero que haga ver que su ruta de trash_can existe y si no, crearla
toolDir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
if [ ! -d "$toolDir/trash_can" ]; then
    mkdir "$toolDir/trash_can"
    chmod 775 "$toolDir/trash_can"
fi

# logica de json presente
if [ ! -f "$toolDir/trash.json" ]; then
    touch "$toolDir/trash.json"
    chmod 775 "$toolDir/trash.json"
    echo '{"fileName":["filePath","trashDate"]}' >> "$toolDir/trash.json"
fi

# logica de python presente
if [ ! -f "$toolDir/trash.py" ]; then
    touch "$toolDir/trash.py"
    chmod 775 "$toolDir/trash.py"

    # START PYTHON SCRIPT TO WRITE
    echo "from datetime import datetime
import platform
import json
import sys
import os

def getRecover(key):
    try:
        f = open('{toolDir}/trash.json'.format(toolDir=toolDir),)
        data = json.load(f)

        # path con el og file name
        path = str(data.get(key)[1])

        # remove the key from json file
        data.pop(key)
        f2 = open('{toolDir}/trash.json'.format(toolDir=toolDir), 'w')
        f2.write(json.dumps(data).replace(\"'\",'\"'))

        fileName = path.split(\"/\")[-1]

        # path con el key file name
        pathWKey = key.join(path.rsplit(fileName, 1))

        # for Windows
        ogpath = path
        ogpathWKey = pathWKey
        if platform.system() == \"Windows\":
            path = path.replace(path[0:2], \"{path}:\".format(path=(path[1]).upper()))
            pathWKey = key.join(path.rsplit(fileName, 1))

        # if file/folder does not exist
        if (not os.path.isfile(path)) and (not os.path.exists(path)):
            # print(\"lo regresamos con su nombre original\")
            print(ogpath)

        # if file/folder exists
        elif (not os.path.isfile(pathWKey)) and (not os.path.exists(pathWKey)):
            # print(\"lo regresamos con su nombre de llave\")
            print(ogpathWKey)

        # fail-safe para por si existe el nombre de la key, se le agregue una nueva fecha al inicio
        else:
            # print(\"og name existia, key name existia, nuevo name con fecha now\")
            print(ogpath.replace((ogpath.split(\"/\")[-1]), \"\")+\"{frmted}-{fileNme}\".format(frmted=(str(datetime.now()).replace(\":\",\".\")).replace(\" \", \"_\"), fileNme=fileName))

        exit()
    except Exception as e:
        #print(e)
        print(\"None\")
    finally:
        if \"f\" in locals(): f.close()
        if \"f2\" in locals(): f2.close()

def getDisplay():
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    BOLD = '\033[1m'
    RESET = '\033[0m'
    
    try:
        f = open('{toolDir}/trash.json'.format(toolDir=toolDir))
        data = json.load(f)
        
        # Print header with bold and blue
        print(f'{BOLD}{BLUE}fileName : trashDate , filePath{RESET}')
        print('-' * 40)  # Separator line
        
        # Skip header and print remaining items in color
        first_item = True
        for item in data:
            if first_item:
                first_item = False
                continue
            print(f'{BLUE}{item}{RESET} : {GREEN}{data.get(item)}{RESET}')
            
        exit()
    except Exception as e:
        print(e)
    finally:
        if 'f' in locals(): f.close()

if __name__ == \"__main__\":
    toolDir = '$toolDir'
    if platform.system() == 'Windows':
        toolDir = toolDir[1:2].upper() + ':' + toolDir[2:-1] + toolDir[toolDir.index(toolDir[-1])]
    if str(sys.argv[1]) == \"d\":
        getDisplay()
    elif str(sys.argv[1]) == \"r\":
        getRecover(sys.argv[2])" >> "$toolDir/trash.py"
    # END OF PYTHON SCRIPT TO WRITE
fi

# logica de python presente
if command -v python &> /dev/null; then
    PYTHON_CMD="python"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
else
    echo "Python is not installed. Please install Python to continue."
    exit 1
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
        echo "$($PYTHON_CMD $toolDir/trash.py d)"
    elif [ $# == 3 ]  && ([ "$2" == "-d" ] || [ "$2" == "--dictionary" ]); then
        echo "$($PYTHON_CMD $toolDir/trash.py d)" | grep $3
    else
        for var in "$@"; do
            if [ "$var" != "-r" ] && [ "$var" != "--recover" ] && [ "$var" != "fileName" ]; then
                recover=$($PYTHON_CMD $toolDir/trash.py r "$var")
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
            rm * -Rf || exit 3
            rm "$toolDir/trash.json"
            echo "emptied trash can"
        else
            echo "trash is already empty"
        fi

    elif [ "$2" == "--older" ]; then
        days_old=$3

        # Read JSON and extract key, date, and path using Python 2
        python_output=$($PYTHON_CMD -c "
import json, sys, time
from datetime import datetime

with open('$toolDir/trash.json', 'r') as f:
    data = json.load(f)

cur_date = '$curDate'  # Read curDate from Bash

# Convert current date to timestamp
cur_timestamp = time.mktime(datetime.strptime(cur_date, '%Y-%m-%d_%H-%M-%S').timetuple())

for key, value in data.items():
    if key == 'fileName':
        continue

    item_date = value[0]  # Get the stored date
    item_timestamp = time.mktime(datetime.strptime(item_date, '%Y-%m-%d_%H-%M-%S').timetuple())

    # Calculate the age in days
    age_days = (cur_timestamp - item_timestamp) / 86400

    # Print items older than days_old
    if age_days > int('$days_old'):
        print('%s|%s|%s' % (key, item_date, value[1]))  # key|date|path
")

        # Process the Python output in Bash
        while IFS="|" read -r key item_date item_path; do
            delete=$($PYTHON_CMD $toolDir/trash.py r "$key")
            if [ "$delete" == "None" ]; then
                echo "No such file or directory" && exit 3
            fi
            cd "$toolDir/trash_can/"
            rm -Rf "$key" || exit 3
            echo "Emptied:      $key ($item_path) is older than $days_old days."
        done <<< "$python_output"

    else
        for var in "$@"; do
            cd "$toolDir"
            if [ "$var" != "-e" ] && [ "$var" != "--empty" ] && [ "$var" != "fileName" ]; then
                delete=$($PYTHON_CMD $toolDir/trash.py r "$var")
                if [ "$delete" == "None" ]; then
                    echo "$var : No such file or directory" && exit 3
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
    file=$(basename -- "$1")
    prevJson=$(echo $(cat "$toolDir/trash.json") | sed 's/.$//')
    fileDir=$(readlink -f "$1") || exit 3
    if [ ! -f "$fileDir" ] && [ ! -d "$fileDir" ]; then
        echo "$fileDir" : No such file or directory.
    elif [ -f "$toolDir/trash_can/$file" ] || [ -d "$toolDir/trash_can/$file" ]; then
        mv "$1" "$toolDir/trash_can/$curDate-$file" || exit 3
        echo "$prevJson,"$'\n'\"$curDate-$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
    else
        mv "$1" "$toolDir/trash_can" || exit 3
        echo "$prevJson,"$'\n'\"$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
    fi

# logica de trash multiple files
else
    for x in "$@"; do
        file=$(basename -- "$x")
        prevJson=$(echo $(cat "$toolDir/trash.json") | sed 's/.$//')
        fileDir=$(readlink -f "$x") || exit 3
        if [ ! -f "$fileDir" ] && [ ! -d "$fileDir" ]; then
            echo "$fileDir" : No such file or directory.
        elif [ -f "$toolDir/trash_can/$file" ] || [ -d "$toolDir/trash_can/$file" ]; then
            mv "$x" "$toolDir/trash_can/$curDate-$file" || exit 3
            echo "$prevJson,"$'\n'\"$curDate-$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
        else
            mv "$x" "$toolDir/trash_can" || exit 3
            echo "$prevJson,"$'\n'\"$file\":[\"$curDate\",\"$fileDir\"]} > "$toolDir/trash.json"
        fi
    done
fi
