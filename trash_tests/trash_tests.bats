#!/usr/bin/env bats

setup() {
  # Detect the operating system
  OS="$(uname)"

  # Determine the shell configuration file based on the OS
  if [ "$OS" = "Darwin" ]; then
      SHELL_CONFIG_FILE="$HOME/.zshrc"
  elif [ "$OS" = "Linux" ]; then
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

  # Source the shell configuration file and extract the alias path
  source "$SHELL_CONFIG_FILE"
  TRASH_SCRIPT_PATH=$(alias trash | sed -E "s/alias trash='(.*)'/\1/")
  TRASH_TOOL_PATH=$(dirname "$TRASH_SCRIPT_PATH")

  # Create a temporary directory for testing
  test_dir=$(mktemp -d)
  cd "$test_dir"
}

teardown() {
  # Clean up after tests
  rm -rf "$test_dir"
}

@test "Check trash_tool path" {
  echo "$TRASH_TOOL_PATH"
  ls "$TRASH_TOOL_PATH"
  [ -d "$TRASH_TOOL_PATH" ]
}

@test "List trash_can directory" {
  run bash "$TRASH_TOOL_PATH/trash.sh" -l
  [ -d "$TRASH_TOOL_PATH/trash_can" ]
}

@test "Check trash.json file" {
  run bash "$TRASH_TOOL_PATH/trash.sh" -l
  [ -f "$TRASH_TOOL_PATH/trash.json" ]
}

@test "Recover file from trash" {
  touch testfile.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" testfile.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" -r testfile.txt
  [ -f "testfile.txt" ]
}

@test "Move file to trash" {
  touch testfile.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" testfile.txt
  [ -f "$TRASH_TOOL_PATH/trash_can/testfile.txt" ]
}

@test "List with regex filter" {
  touch file1.txt file2.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" file1.txt file2.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" -l "file1"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "file1.txt" ]]
}

@test "Recursive listing" {
    mkdir -p dir1/dir2
    touch dir1/dir2/file.txt
    run bash "$TRASH_TOOL_PATH/trash.sh" dir1
    run bash "$TRASH_TOOL_PATH/trash.sh" -l -R
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "total" ]]
    [[ "${output}" =~ "drwx" ]]
    [[ "${output}" =~ "staff" ]]
}

@test "Select specific folder" {
  mkdir -p dir1/dir2
  touch dir1/dir2/file.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" dir1
  run bash "$TRASH_TOOL_PATH/trash.sh" -l -s dir1
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "dir1" ]]
}

@test "Empty trash older than N days" {
  touch oldfile.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" oldfile.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" -e --older 0
  [ ! -f "$TRASH_TOOL_PATH/trash_can/oldfile.txt" ]
}

@test "Multiple file trash" {
  touch file1.txt file2.txt file3.txt
  run bash "$TRASH_TOOL_PATH/trash.sh" file1.txt file2.txt file3.txt
  [ -f "$TRASH_TOOL_PATH/trash_can/file1.txt" ]
  [ -f "$TRASH_TOOL_PATH/trash_can/file2.txt" ]
  [ -f "$TRASH_TOOL_PATH/trash_can/file3.txt" ]
}

@test "Empty file from trash" {
  run bash "$TRASH_TOOL_PATH/trash.sh" -e testfile.txt
  [ ! -f "$TRASH_TOOL_PATH/trash_can/testfile.txt" ]
}

@test "Multiple file emptying" {
  run bash "$TRASH_TOOL_PATH/trash.sh" -e file1.txt file2.txt file3.txt
  [ ! -f "$TRASH_TOOL_PATH/trash_can/file1.txt" ]
  [ ! -f "$TRASH_TOOL_PATH/trash_can/file2.txt" ]
  [ ! -f "$TRASH_TOOL_PATH/trash_can/file3.txt" ]
}
