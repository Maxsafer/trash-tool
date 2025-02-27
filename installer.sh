#!/bin/sh
set -eu

# Enable non-interactive mode if passed as an argument
NONINTERACTIVE=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            NONINTERACTIVE=1
            ;;
    esac
done

# Interactive Behavior Notice:
# This installer may prompt the user if conflicts are detected (e.g. an existing symlink).
# To run in non-interactive mode (suppressing prompts), include the -y or --yes flag.
# Example (non-interactive):
#   /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/freedtspec/installer.sh)" -y

# Define installation paths
INSTALL_DIR="$HOME/trash_tool"
BIN_DIR="$HOME/.local/bin"  # User-specific bin directory
SCRIPT_NAME="trash.sh"
SCRIPT_URL="https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/freedtspec/trash.sh"

# Function to append a line to a file if an export for BIN_DIR is not already present.
append_if_not_exists() {
    file="$1"
    line="$2"
    if [ -f "$file" ]; then
        escaped_bin=$(printf '%s\n' "$BIN_DIR" | sed 's/[][\/.^$*]/\\&/g')
        if grep -E -q '^[[:space:]]*[^#]*export[[:space:]]+PATH=.*'"$escaped_bin" "$file"; then
            echo "A PATH entry for $BIN_DIR already exists in $file."
        else
            echo "$line" >> "$file"
            echo "Updated $file with: $line"
        fi
    else
        echo "$line" > "$file"
        echo "Created $file and added: $line"
    fi
}

# Check for a download tool: prefer curl but fallback to wget if needed
if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    echo "Error: Neither curl nor wget is installed. Please install one of them." >&2
    exit 1
fi

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# Determine which profile file to update for login shells
if [ -f "$HOME/.bash_profile" ]; then
    PROFILE_FILE="$HOME/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
    PROFILE_FILE="$HOME/.profile"
else
    PROFILE_FILE="$HOME/.profile"
fi

# Update PATH for various shells if BIN_DIR is not already in PATH
case ":$PATH:" in
    *":$BIN_DIR:"*)
        ;;
    *)
        PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'
        append_if_not_exists "$PROFILE_FILE" "$PATH_EXPORT"
        append_if_not_exists "$HOME/.bashrc" "$PATH_EXPORT"
        append_if_not_exists "$HOME/.zshrc" "$PATH_EXPORT"

        # For Fish shell configuration
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        mkdir -p "$(dirname "$FISH_CONFIG")"
        FISH_PATH_EXPORT='set -gx PATH "$HOME/.local/bin" $PATH'
        append_if_not_exists "$FISH_CONFIG" "$FISH_PATH_EXPORT"

        # Apply immediately for current session
        export PATH="$HOME/.local/bin:$PATH"
        ;;
esac

# Check if INSTALL_DIR exists but is not a directory
if [ -e "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR" ]; then
    echo "Error: $INSTALL_DIR exists and is not a directory. Please remove or rename it." >&2
    exit 1
fi

# Create the trash_tool directory with secure permissions if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -m 700 "$INSTALL_DIR" || { echo "Failed to create directory $INSTALL_DIR; please check permissions." >&2; exit 1; }
    echo "Created directory: $INSTALL_DIR"
else
    echo "'$INSTALL_DIR' already exists, updating $SCRIPT_NAME only."
fi

cd "$INSTALL_DIR" || { echo "Failed to access $INSTALL_DIR; please check permissions." >&2; exit 1; }

# Download the latest trash.sh script and verify that the file is not empty.
if [ "$DOWNLOADER" = "curl" ]; then
    if ! curl -sS "$SCRIPT_URL" -o "$SCRIPT_NAME"; then
        echo "Download failed. Please check your network connection." >&2
        exit 1
    fi
elif [ "$DOWNLOADER" = "wget" ]; then
    if ! wget -qO "$SCRIPT_NAME" "$SCRIPT_URL"; then
        echo "Download failed. Please check your network connection." >&2
        exit 1
    fi
fi

if [ ! -s "$SCRIPT_NAME" ]; then
    echo "Downloaded script is empty. Exiting." >&2
    exit 1
fi

chmod 700 "$SCRIPT_NAME"

# Function to create (or update) a symlink, verifying if it already exists in BIN_DIR.
create_symlink() {
    link_name="$1"
    target="$2"
    
    if [ -L "$link_name" ]; then
        current_target=$(readlink "$link_name")
        if [ "$current_target" = "$target" ]; then
            echo "Symlink $(basename "$link_name") already exists and points to the correct target."
            return 0
        else
            if [ "$NONINTERACTIVE" -eq 1 ]; then
                ln -sf "$target" "$link_name"
                echo "Symlink $(basename "$link_name") overwritten automatically."
            else
                echo -n "Symlink $(basename "$link_name") exists and points to $current_target. Overwrite with $target? [y/N]: "
                read answer
                case "$answer" in
                    [Yy])
                        ln -sf "$target" "$link_name"
                        echo "Symlink $(basename "$link_name") overwritten."
                        ;;
                    *)
                        echo "Skipping creation of symlink $(basename "$link_name")."
                        ;;
                esac
            fi
        fi
    elif [ -e "$link_name" ]; then
        echo "Error: $link_name exists and is not a symlink. Please remove or rename it." >&2
        exit 1
    else
        ln -sf "$target" "$link_name"
        echo "Created symlink $(basename "$link_name")."
    fi
}

# Create symbolic links in ~/.local/bin for 'trash' and 'ts'
create_symlink "$BIN_DIR/trash" "$INSTALL_DIR/$SCRIPT_NAME"
create_symlink "$BIN_DIR/ts" "$INSTALL_DIR/$SCRIPT_NAME"

# Verify installation
if command -v trash >/dev/null 2>&1 && command -v ts >/dev/null 2>&1; then
    echo "Installation successful! You can now use 'trash' or 'ts'."
    echo "Try running: . ~/.bashrc or restarting your terminal."
else
    echo "Installation completed, but symbolic links may not be recognized immediately."
    echo "Try running: . ~/.bashrc or restarting your terminal."
fi
