#!/bin/bash

# Create directory with user-only permissions
if [ ! -d "trash_tool" ]; then
    mkdir -m 700 trash_tool || (echo "Failed to create directory, please check permissions." && exit 1)
elif [ -d "trash_tool" ]; then
    echo "'trash_tool' already exists, updating trash.sh only."
else
    echo "Unexpected directory error, please check permissions." && exit 1
fi

cd trash_tool || (echo "Failed to access trash_tool directory, please check permissions." && exit 1)
toolDir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

# Download and set execute permissions for the refined trash.sh script.
curl https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/main/trash.sh -o trash.sh
chmod 700 trash.sh

# NOTE: The new refined version no longer uses trash_parser.sh, so we are not downloading it.

# Detect the operating system
OS="$(uname)"

# Determine the shell configuration file based on the OS and shell being used.
if [ "$OS" = "Darwin" ]; then
    # macOS typically uses zsh by default.
    SHELL_CONFIG_FILE="$HOME/.zshrc"
elif [ "$OS" = "Linux" ]; then
    # Check which shell is being used.
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_CONFIG_FILE="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_CONFIG_FILE="$HOME/.bashrc"
    else
        echo "Unsupported shell. Please add the alias manually."
        exit 1
    fi
else
    echo "Unsupported operating system. Please add the alias manually."
    exit 1
fi

# Append the alias to the determined shell configuration file if not already present.
if ! grep -q "alias trash=" "$SHELL_CONFIG_FILE"; then
    echo "alias trash='$toolDir/trash.sh'" >> "$SHELL_CONFIG_FILE"
    echo "alias ts='$toolDir/trash.sh'" >> "$SHELL_CONFIG_FILE"
    echo "Alias 'trash' and 'ts' added to $SHELL_CONFIG_FILE. Please run 'source $SHELL_CONFIG_FILE' to start using trash."
else
    echo "Trash alias already exists in $SHELL_CONFIG_FILE"
fi