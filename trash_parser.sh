#!/bin/bash

# remove trailing slash
sanitize_path() {
    echo "${1%/}"
}

# SEGUIR PROBANDO, PERO PARECE QUE FUNCIONA
parse_json() {
    local json_file=$1
    local query_key=$2
    local remove_key=$3
    
    # Read and normalize JSON
    local json=$(cat "$json_file" | tr -d '\n\r' | sed 's/[[:space:]]*//g')
    
    if [[ -n "$remove_key" ]]; then
        remove_key=$(sanitize_path "$remove_key")
        # Extract the path before removing the entry
        local path=$(echo "$json" | grep -o "\"$remove_key\":\[[^]]*\]" | grep -o '"[^"]*"' | tail -n 1 | tr -d '"')
        # Use the same pattern matching from query to remove the entry
        local new_json=$(echo "$json" | sed "s/,\"$remove_key\":\[[^]]*\]//g" | sed "s/\"$remove_key\":\[[^]]*\],//g")
        if [[ "$new_json" != "$json" ]]; then
            printf "%s" "$new_json" > "$json_file"
            
            # Get the original filename without path
            local filename=$(basename "$path")
            local dirpath=$(dirname "$path")
            local path_with_key="${dirpath}/${remove_key}"
            
            # Check paths and return appropriate value
            if [[ ! -e "$path" && ! -f "$path" ]]; then
                echo "$path"
            elif [[ ! -e "$path_with_key" && ! -f "$path_with_key" ]]; then
                echo "$path_with_key"
            else
                # Generate timestamp in the required format
                local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
                echo "${dirpath}/${timestamp}-${filename}"
            fi
        else
            echo "None"
        fi
        return
    fi
    
    # Query functionality (already working perfectly)
    if [[ -n "$query_key" && "$json" =~ \"$query_key\":(\[[^\]]+\]) ]]; then
        printf "%s: %s\n" "$query_key" "${BASH_REMATCH[1]}"
    fi

    # List all
    if [[ "$query_key" == "--list-all" ]]; then
        # If being piped (no TTY), output raw format
        if [ ! -t 1 ] && [ -z "$FORCE_PRETTY" ]; then
            while [[ "$json" =~ \"([^\"]+)\":\[\"([^\"]+)\",\"([^\"]+)\"\] ]]; do
                if [ "${BASH_REMATCH[1]}" != "fileName" ]; then
                    echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}"
                fi
                json="${json#*"${BASH_REMATCH[0]}"}"
            done
            return
        fi

        # Colors for terminal display
        BLUE='\033[0;94m'
        GREEN='\033[0;92m'
        WHITE='\033[0;37m'
        BOLD='\033[0;1m'
        NC='\033[0m' # No Color

        # Header with fixed width
        printf "${BOLD}${BLUE}%-30s %-25s %-s${NC}\n" "fileName" "trashDate" "filePath"
        printf "${WHITE}%.0s-" {1..80}  # Prints 80 dashes
        printf "\n"
        
        while [[ "$json" =~ \"([^\"]+)\":\[\"([^\"]+)\",\"([^\"]+)\"\] ]]; do
            if [ "${BASH_REMATCH[1]}" != "fileName" ]; then
                printf "${GREEN}%-30s %-25s %-s${NC}\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
            fi
            json="${json#*"${BASH_REMATCH[0]}"}"
        done
    fi
}

# Main argument parsing remains the same
if [ $# -lt 1 ]; then
    echo "Usage: $0 <json-file> [--query <key>] [--remove <key>] [--list-all]"
    exit 1
fi

json_file=$1
shift
query_key=""
remove_key=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --query)
            query_key=$2
            shift 2
            ;;
        --remove)
            remove_key=$2
            shift 2
            ;;
        --list-all)
            parse_json "$json_file" "--list-all"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

parse_json "$json_file" "$query_key" "$remove_key"
