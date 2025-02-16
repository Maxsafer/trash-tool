#!/bin/bash

mkdir trash_tool
chmod 775 trash_tool
cd trash_tool

toolDir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)

curl https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/main/trash.sh -o trash.sh
chmod u+x trash.sh
chmod 775 trash.sh

# Check if trash.py exists and delete it if it does
if [ -f "trash.py" ]; then
    rm "trash.py"
fi

# Detect the operating system
OS="$(uname)"

# Determine the shell configuration file based on the OS
if [ "$OS" = "Darwin" ]; then
    # macOS typically uses zsh by default
    SHELL_CONFIG_FILE="$HOME/.zshrc"
elif [ "$OS" = "Linux" ]; then
    # Check which shell is being used
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

# Append the alias to the determined shell configuration file
if ! grep -q "alias trash=" "$SHELL_CONFIG_FILE"; then
    echo "alias trash='$toolDir/trash.sh'" >> "$SHELL_CONFIG_FILE"
    echo "alias ts='$toolDir/trash.sh'" >> "$SHELL_CONFIG_FILE"
    source $SHELL_CONFIG_FILE
    echo "Alias 'trash' and 'ts' added to $SHELL_CONFIG_FILE. Sourcing $SHELL_CONFIG_FILE... Use trash -h for help."
else
    echo "Trash alias already exists in $SHELL_CONFIG_FILE"
fi

# Detect Python command
if command -v python &> /dev/null; then
    PYTHON_CMD="python"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
else
    echo "Python is not installed. Please install Python to continue."
    exit 1
fi

# Check Python version
PYTHON_VERSION="$($PYTHON_CMD -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
REQUIRED_VERSION="2.6.6"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then 
    echo "Python version $PYTHON_VERSION detected, installed version meets the requirement."
else
    echo "Warning: Python version $REQUIRED_VERSION or higher is required. Current version is $PYTHON_VERSION"
fi
