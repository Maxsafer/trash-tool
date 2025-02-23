#!/bin/bash

# Define installation paths
INSTALL_DIR="$HOME/trash_tool"
BIN_DIR="$HOME/.local/bin"  # User-specific bin directory
SCRIPT_NAME="trash.sh"

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# Determine which profile file to update for bash users
if [ -f "$HOME/.bash_profile" ]; then
    PROFILE_FILE="$HOME/.bash_profile"  # Fedora, RHEL, CentOS, some distros
elif [ -f "$HOME/.profile" ]; then
    PROFILE_FILE="$HOME/.profile"  # Debian, Ubuntu, default fallback
else
    PROFILE_FILE="$HOME/.profile"  # If neither exists, create this one
fi

# Ensure ~/.local/bin is in PATH for all shells
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE_FILE"  # For login shells
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"   # Bash interactive shells
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"    # macOS zsh users
    export PATH="$HOME/.local/bin:$PATH"  # Apply immediately
fi

# Create the trash_tool directory with secure permissions
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -m 700 "$INSTALL_DIR" || { echo "Failed to create directory, please check permissions."; exit 1; }
    echo "Created directory: $INSTALL_DIR"
elif [ -d "$INSTALL_DIR" ]; then
    echo "'$INSTALL_DIR' already exists, updating $SCRIPT_NAME only."
else
    echo "Unexpected directory error, please check permissions." && exit 1
fi

cd "$INSTALL_DIR" || { echo "Failed to access $INSTALL_DIR, please check permissions."; exit 1; }

# Download the latest trash.sh script
curl -sS https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/freedtspec/trash.sh -o "$SCRIPT_NAME"
chmod 700 "$SCRIPT_NAME"

# Create symbolic links in ~/.local/bin
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$BIN_DIR/trash"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$BIN_DIR/ts"

# Ensure symbolic links are executable
chmod +x "$BIN_DIR/trash" "$BIN_DIR/ts"

# Verify installation
if command -v trash >/dev/null && command -v ts >/dev/null; then
    echo "Installation successful! You can now use 'trash' or 'ts'."
else
    echo "Installation completed, but symbolic links may not be recognized immediately."
    echo "Try running: source ~/.bashrc or restarting your terminal."
fi
