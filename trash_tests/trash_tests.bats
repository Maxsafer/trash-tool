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

@test "File collision handling" {
    touch original.txt
    run bash "$TRASH_TOOL_PATH/trash.sh" original.txt
    touch original.txt
    run bash "$TRASH_TOOL_PATH/trash.sh" original.txt
    [ -f "$TRASH_TOOL_PATH/trash_can/original.txt" ]
    # Check for UUID pattern in filename
    [[ -n $(find "$TRASH_TOOL_PATH/trash_can" -name "*-original.txt" -type f) ]]
}

@test "Directory collision with nested structure" {
    mkdir -p dir1/subdir/deepdir
    touch dir1/subdir/file1.txt dir1/subdir/deepdir/file2.txt
    run bash "$TRASH_TOOL_PATH/trash.sh" dir1
    mkdir -p dir1/subdir/deepdir
    touch dir1/subdir/file3.txt
    run bash "$TRASH_TOOL_PATH/trash.sh" dir1
    [ -d "$TRASH_TOOL_PATH/trash_can/dir1" ]
    [[ -n $(find "$TRASH_TOOL_PATH/trash_can" -name "*-dir1" -type d) ]]
}

@test "Nested directory recovery with collisions" {
    mkdir -p dir1/subdir
    touch dir1/subdir/file1.txt
    orig_path=$(pwd)
    run bash "$TRASH_TOOL_PATH/trash.sh" dir1
    mkdir -p dir1
    recovered_output=$(bash "$TRASH_TOOL_PATH/trash.sh" -r dir1)
    recovered_dir=$(echo "$recovered_output" | awk -F "to " '{print $2}' | xargs)
    [[ -d "$recovered_dir/subdir" ]]
    [[ -f "$recovered_dir/subdir/file1.txt" ]]
}

@test "Multiple directory level collisions" {
    mkdir -p dir1/dir2/dir3
    touch dir1/dir2/dir3/file.txt
    run bash "$TRASH_TOOL_PATH/trash.sh" dir1
    mkdir -p dir1/dir2/dir3
    run bash "$TRASH_TOOL_PATH/trash.sh" dir1
    [ -d "$TRASH_TOOL_PATH/trash_can/dir1" ]
    [[ -n $(find "$TRASH_TOOL_PATH/trash_can" -name "*-dir1" -type d) ]]
}

@test "Handle special characters in filenames" {
    touch "file with spaces.txt"
    touch "file-with-@-symbol.txt"
    touch "file#with#hash.txt"
    run bash "$TRASH_TOOL_PATH/trash.sh" "file with spaces.txt" "file-with-@-symbol.txt" "file#with#hash.txt"
    [ -f "$TRASH_TOOL_PATH/trash_can/file with spaces.txt" ]
    [ -f "$TRASH_TOOL_PATH/trash_can/file-with-@-symbol.txt" ]
    [ -f "$TRASH_TOOL_PATH/trash_can/file#with#hash.txt" ]
}

@test "Handle unicode characters in filenames" {
    touch "file-with-üñîçødë.txt"
    run bash "$TRASH_TOOL_PATH/trash.sh" "file-with-üñîçødë.txt"
    [ -f "$TRASH_TOOL_PATH/trash_can/file-with-üñîçødë.txt" ]
}

@test "Handle file with no read permission" {
    touch "no_read_permission.txt"
    chmod -r "no_read_permission.txt"
    run bash "$TRASH_TOOL_PATH/trash.sh" "no_read_permission.txt"
    [ -f "$TRASH_TOOL_PATH/trash_can/no_read_permission.txt" ]
}

@test "Handle file with no write permission" {
    touch "no_write_permission.txt"
    chmod -w "no_write_permission.txt"
    run bash "$TRASH_TOOL_PATH/trash.sh" "no_write_permission.txt"
    [ -f "$TRASH_TOOL_PATH/trash_can/no_write_permission.txt" ]
}

@test "Handle corrupted JSON file" {
    # Write corrupted content to the JSON file
    echo "corrupted content" > "$TRASH_TOOL_PATH/trash.json"
    run bash "$TRASH_TOOL_PATH/trash.sh" -r -d 2>&1
    echo "$output"
    [[ "$output" == "Error: Corrupted JSON file." ]]
}

@test "Simulate corrupted JSON by removing last curly bracket" {
    run bash "$TRASH_TOOL_PATH/trash.sh" -e --confirm
    run bash "$TRASH_TOOL_PATH/trash.sh"
    # Remove the last curly bracket from the JSON file
    sed -i '' '$ s/}$//' "$TRASH_TOOL_PATH/trash.json"
    run bash "$TRASH_TOOL_PATH/trash.sh" -r -d 2>&1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: Corrupted JSON file."* ]]
}

@test "Simulate corrupted JSON by deleting a chunk" {
    echo "{\"key\":[\"value1\",\"value2\"]}" > "$TRASH_TOOL_PATH/trash.json"
    # Delete a specific key-value pair from the JSON file
    sed -i '' '/"key":\[.*\]/d' "$TRASH_TOOL_PATH/trash.json"
    run bash "$TRASH_TOOL_PATH/trash.sh" -r -d 2>&1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: Corrupted JSON file."* ]]
}

@test "Handle empty JSON file" {
    run bash "$TRASH_TOOL_PATH/trash.sh" -e --confirm
    run bash "$TRASH_TOOL_PATH/trash.sh"
    echo "" > "$TRASH_TOOL_PATH/trash.json"
    run bash "$TRASH_TOOL_PATH/trash.sh" -l
    [ "$status" -eq 0 ]  # Should handle gracefully
}
