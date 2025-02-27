#!/usr/bin/env bats

setup() {
  # Detect the operating system (for later use if needed)
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
          echo "Unsupported shell."
          exit 1
      fi
  else
      echo "Unsupported operating system."
      exit 1
  fi

  # Source the shell configuration file and extract the alias path.
  # (Assumes that the alias exists; if not, this test might fail.)
  . "$SHELL_CONFIG_FILE"
  TRASH_SCRIPT_PATH=$(alias trash | sed -E "s/alias trash='(.*)'/\1/")
  TRASH_TOOL_PATH=$(dirname "$TRASH_SCRIPT_PATH")

  # Create a temporary directory for testing.
  test_dir=$(mktemp -d)
  cd "$test_dir"
  
  # Override XDG_DATA_HOME so our tests do not affect the real trash.
  export XDG_DATA_HOME="$test_dir/xdg"
}

teardown() {
  # Clean up after tests
  rm -rf "$test_dir"
}

@test "Check trash tool path" {
  echo "$TRASH_TOOL_PATH"
  ls "$TRASH_TOOL_PATH"
  [ -d "$TRASH_TOOL_PATH" ]
}

@test "Check trash directory exists" {
  run sh "$TRASH_TOOL_PATH/trash.sh" -l
  # New code creates trash in $XDG_DATA_HOME/Trash/files and /info
  [ -d "$XDG_DATA_HOME/Trash/files" ]
  [ -d "$XDG_DATA_HOME/Trash/info" ]
}

@test "Recover file from trash" {
  touch testfile.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" testfile.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" -r testfile.txt
  [ -f "testfile.txt" ]
}

@test "Move file to trash" {
  touch testfile.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" testfile.txt
  [ -f "$XDG_DATA_HOME/Trash/files/testfile.txt" ]
}

@test "List with regex filter" {
  touch file1.txt file2.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" file1.txt file2.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" -l "file1"
  [ "$status" -eq 0 ]
  # Check that output contains "file1.txt"
  echo "$output" | grep -q "file1.txt"
}

@test "Recursive listing" {
    mkdir -p dir1/dir2
    touch dir1/dir2/file.txt
    run sh "$TRASH_TOOL_PATH/trash.sh" dir1
    run sh "$TRASH_TOOL_PATH/trash.sh" -l -R
    [ "$status" -eq 0 ]
    # Check that output contains "total" (may vary by ls output)
    echo "$output" | grep -q "total"
}

@test "Select specific folder" {
  mkdir -p dir1/dir2
  touch dir1/dir2/file.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" dir1
  run sh "$TRASH_TOOL_PATH/trash.sh" -l -s dir1
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "dir1"
}

@test "Empty trash older than N days" {
  touch oldfile.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" oldfile.txt
  # Using --older 0 should remove all trashed items
  run sh "$TRASH_TOOL_PATH/trash.sh" -e --older 0
  [ ! -f "$XDG_DATA_HOME/Trash/files/oldfile.txt" ]
}

@test "Multiple file trash" {
  touch file1.txt file2.txt file3.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" file1.txt file2.txt file3.txt
  [ -f "$XDG_DATA_HOME/Trash/files/file1.txt" ]
  [ -f "$XDG_DATA_HOME/Trash/files/file2.txt" ]
  [ -f "$XDG_DATA_HOME/Trash/files/file3.txt" ]
}

@test "Empty specific file from trash" {
  touch testfile.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" testfile.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" -e testfile.txt
  [ ! -f "$XDG_DATA_HOME/Trash/files/testfile.txt" ]
}

@test "Multiple file emptying" {
  touch file1.txt file2.txt file3.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" file1.txt file2.txt file3.txt
  run sh "$TRASH_TOOL_PATH/trash.sh" -e file1.txt file2.txt file3.txt
  [ ! -f "$XDG_DATA_HOME/Trash/files/file1.txt" ]
  [ ! -f "$XDG_DATA_HOME/Trash/files/file2.txt" ]
  [ ! -f "$XDG_DATA_HOME/Trash/files/file3.txt" ]
}

@test "File collision handling" {
    touch original.txt
    run sh "$TRASH_TOOL_PATH/trash.sh" original.txt
    touch original.txt
    run sh "$TRASH_TOOL_PATH/trash.sh" original.txt
    [ -f "$XDG_DATA_HOME/Trash/files/original.txt" ]
    result=$(find "$XDG_DATA_HOME/Trash/files" -name "original.txt-*" -type f)
    [ -n "$result" ]
}

@test "Directory collision with nested structure" {
    mkdir -p dir1/subdir/deepdir
    touch dir1/subdir/file1.txt dir1/subdir/deepdir/file2.txt
    run sh "$TRASH_TOOL_PATH/trash.sh" dir1
    mkdir -p dir1/subdir/deepdir
    touch dir1/subdir/file3.txt
    run sh "$TRASH_TOOL_PATH/trash.sh" dir1
    [ -d "$XDG_DATA_HOME/Trash/files/dir1" ]
    result=$(find "$XDG_DATA_HOME/Trash/files" -name "dir1-*" -type d)
    [ -n "$result" ]
}

@test "Nested directory recovery with collisions" {
    mkdir -p dir1/subdir
    touch dir1/subdir/file1.txt
    orig_path=$(pwd)
    run sh "$TRASH_TOOL_PATH/trash.sh" dir1
    # Simulate a collision by recreating dir1 at the original location
    mkdir -p dir1
    recovered_output=$(sh "$TRASH_TOOL_PATH/trash.sh" -r dir1)
    recovered_dir=$(echo "$recovered_output" | awk -F "Recovered: " '{print $2}' | xargs)
    [ -d "$recovered_dir/subdir" ]
    [ -f "$recovered_dir/subdir/file1.txt" ]
}

@test "Multiple directory level collisions" {
    mkdir -p dir1/dir2/dir3
    touch dir1/dir2/dir3/file.txt
    run sh "$TRASH_TOOL_PATH/trash.sh" dir1
    mkdir -p dir1/dir2/dir3
    run sh "$TRASH_TOOL_PATH/trash.sh" dir1
    [ -d "$XDG_DATA_HOME/Trash/files/dir1" ]
    result=$(find "$XDG_DATA_HOME/Trash/files" -name "dir1-*" -type d)
    [ -n "$result" ]
}

@test "Handle special characters in filenames" {
    touch "file with spaces.txt"
    touch "file-with-@-symbol.txt"
    touch "file#with#hash.txt"
    run sh "$TRASH_TOOL_PATH/trash.sh" "file with spaces.txt" "file-with-@-symbol.txt" "file#with#hash.txt"
    [ -f "$XDG_DATA_HOME/Trash/files/file with spaces.txt" ]
    [ -f "$XDG_DATA_HOME/Trash/files/file-with-@-symbol.txt" ]
    [ -f "$XDG_DATA_HOME/Trash/files/file#with#hash.txt" ]
}

@test "Handle unicode characters in filenames" {
    touch "file-with-üñîçødë.txt"
    run sh "$TRASH_TOOL_PATH/trash.sh" "file-with-üñîçødë.txt"
    [ -f "$XDG_DATA_HOME/Trash/files/file-with-üñîçødë.txt" ]
}

@test "Handle file with no read permission" {
    touch "no_read_permission.txt"
    chmod a-r "no_read_permission.txt"
    run sh "$TRASH_TOOL_PATH/trash.sh" "no_read_permission.txt"
    [ -f "$XDG_DATA_HOME/Trash/files/no_read_permission.txt" ]
}

@test "Handle file with no write permission" {
    touch "no_write_permission.txt"
    chmod a-w "no_write_permission.txt"
    run sh "$TRASH_TOOL_PATH/trash.sh" "no_write_permission.txt"
    [ -f "$XDG_DATA_HOME/Trash/files/no_write_permission.txt" ]
}
