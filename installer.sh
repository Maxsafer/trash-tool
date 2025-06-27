#!/bin/bash
set -euo pipefail

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
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/mac/installer.sh)" -y

# Define installation paths
INSTALL_DIR="$HOME/trash_tool"
BIN_DIR="$HOME/.local/bin"  # User-specific bin directory
SCRIPT_NAME="trash.sh"
SCRIPT_URL="https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/mac/trash.sh"

if [[ $(id -u) -ne 0 ]]; then
    echo "Run me with sudo:  sudo $0"
    exit 1
fi

# Function to append a line to a file if an export for BIN_DIR is not already present,
# using regex for a more robust check.
append_if_not_exists() {
    local file="$1"
    local line="$2"
    if [ -f "$file" ]; then
        # Escape potential regex special characters in BIN_DIR
        local escaped_bin
        escaped_bin=$(printf '%s\n' "$BIN_DIR" | sed 's/[][\/.^$*]/\\&/g')
        # Look for an uncommented export PATH line that contains BIN_DIR, with flexible spacing.
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
if command -v curl >/dev/null; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null; then
    DOWNLOADER="wget"
else
    echo "Error: Neither curl nor wget is installed. Please install one of them." >&2
    exit 1
fi

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# Determine which profile file to update for bash users
if [ -f "$HOME/.bash_profile" ]; then
    PROFILE_FILE="$HOME/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
    PROFILE_FILE="$HOME/.profile"
else
    PROFILE_FILE="$HOME/.profile"
fi

# Update PATH for various shells if BIN_DIR is not already in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
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
fi

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

# Download the latest trash.sh script with verification that the file is not empty.
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

# Ensure the downloaded script is not empty
if [ ! -s "$SCRIPT_NAME" ]; then
    echo "Downloaded script is empty. Exiting." >&2
    exit 1
fi

# Set secure permissions on the script
chmod 700 "$SCRIPT_NAME"

# Function to create (or update) a symlink, verifying if it already exists in BIN_DIR.
create_symlink() {
    local link_name="$1"
    local target="$2"
    
    if [ -L "$link_name" ]; then
        # If it's a symlink, check its target.
        local current_target
        current_target=$(readlink "$link_name")
        if [ "$current_target" = "$target" ]; then
            echo "Symlink $(basename "$link_name") already exists and points to the correct target."
            return 0
        else
            if [ "$NONINTERACTIVE" -eq 1 ]; then
                ln -sf "$target" "$link_name"
                echo "Symlink $(basename "$link_name") overwritten automatically."
            else
                read -p "Symlink $(basename "$link_name") exists and points to $current_target. Overwrite with $target? [y/N]: " answer
                if [[ "$answer" =~ ^[Yy]$ ]]; then
                    ln -sf "$target" "$link_name"
                    echo "Symlink $(basename "$link_name") overwritten."
                else
                    echo "Skipping creation of symlink $(basename "$link_name")."
                fi
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

# Verifies that cron is enabled and running
cron_enable_start() {
  local SERVICE="com.vix.cron"

  # Enable if disabled
  if launchctl print-disabled system 2>/dev/null | grep -q "\"com.vix.cron\" => \(true\|disabled\)"; then
    echo "→ Enabling $SERVICE"
    launchctl enable system/$SERVICE 
    echo "✓ $SERVICE enabled"

  else
    echo "✓ $SERVICE already enabled"
  fi

  # Start if not running
  if ! launchctl list | grep -q "$SERVICE"; then
    echo "→ Starting $SERVICE"
    launchctl start system/$SERVICE
    echo "✓ $SERVICE running"
  else
    echo "✓ $SERVICE already running"
  fi
}

# Create symbolic links in ~/.local/bin for 'ts'
create_symlink "$BIN_DIR/ts" "$INSTALL_DIR/$SCRIPT_NAME"

# Set cron for MacOS
cron_enable_start

# Verify installation
if command -v ts >/dev/null && command -v ts >/dev/null; then
    echo "Installation successful! You can now use 'ts'."
else
    echo "Installation completed, but symbolic links may not be recognized immediately."
    echo "Try running: source ~/.bashrc or restarting your terminal."
fi
