# Trash Tool (CLI Utility)
This tool is a Bash utility designed to manage files and directories by moving them to a designated "trash can" directory, allowing for recovery or permanent deletion at a later time. This utility mimics a recycle bin or trash functionality commonly found in graphical operating systems but is implemented for command-line environments. Below is a detailed high-level documentation of this tool, including its functionality and usage examples.

I came up with this idea when I was working on a highly restrictive Linux environment, that is why only Python 2.6.6 or higher is needed as a dependency. It also works at the permission level you configure it to run at.

## Installation:
Navigate to the desired installation path and run:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/main/installer.sh)"
```
This will create a new folder called `trash_tool` and it will add the following aliases `ts` and `trash`. If these are not recognized, manually source the displayed file.

Running this installer more than once will not mess with your previously trashed files, but moving the installation folder or renaming it will cause the aliases to break.

## Overview:

The tool performs the following main functions:

* Initializes a trash directory and associated metadata files if they do not exist.
* Provides commands to list, recover, and permanently delete files from the trash.
* Supports scheduling automatic trash emptying using cron jobs.
* Offers a help menu to guide users on how to use the tool.

## Initialization:

The script sets up a directory named trash_can in the same location as the script itself to store trashed files.
It creates a trash.json file to keep track of the original file paths and the date they were trashed.
A Python script trash.py is generated to handle JSON operations for displaying and recovering files.

## Key Functionalities:

### Listing Files:

`-l` or `--list`: Lists files in the trash can. Supports optional recursive listing and filtering by text or regex.

**Example:** `ts -l` lists all files, `trash -l -R` lists all files recursively, and `trash -l -s some-folder filter` filters the recursively listed trash selected folder by text or regex.

### Recovering Files:

`-r` or `--recover`: Recovers specified files from the trash can.

`-d` or `--dictionary`: Displays the dictionary of trashed files, optionally filtered by text or regex.

**Example:** `ts -r file1` recovers file1, `trash -r -d` displays the dictionary for all trashed files.

### Emptying Trash:

`-e` or `--empty`: Permanently deletes files from the trash can.

`--confirm`: Empties the entire trash can.

`--older [days]`: Deletes only files older than the specified number of days.

**Example:** `ts -e file1` deletes file1, `trash -e --confirm` empties the entire trash can, `ts -e --older 30` deletes every file older than 30 days.

### Cron Job Management:

`-c` or `--cron`: Manages automated trash emptying via cron.

`-p` or `--print`: Displays the current cron job related to trash.

`-t` or `--time [days]`: Sets up automatic emptying of trash every N days.

`-o` or `--older [days]`: Deletes files older than N days when emptying.

**Example:** `ts -c -t 7` sets up a cron job to empty trash every 7 days, `trash --cron --time 7 --older 30` sets up a cron job to empty trash every 7 days that is older than 30 days.

### Help:

`-h` or `--help`: Displays the help menu with usage instructions.
```
Trash Tool v1.1
 
Usage: trash [OPTION] SOURCE
Usage: ts [OPTION] SOURCE
 
Tool documentation: https://github.com/Maxsafer/trash-tool
 
Argument list:
-h, --help            Display this help menu.
-l, --list            List files inside the trash can.
                      [Optional: Can include a text/regex filter]
                          e.g.    trash -l [text/regex]
   -R, --Recursive    Recursively list all items in the trash can.
                      [Optional: Can include a text/regex filter]
                          e.g.    trash -l -R [text/regex]
   -s, --select       List a specific trashed file/folder recursively.
                      [Optional: Can include a text/regex filter]
                          e.g.    trash -l -s folder [text/regex]
 
[no argument]         Move file(s)/folder(s) to the trash.
                          e.g.    trash file1 file2 ...
 
-r, --recover         Recover file(s)/folder(s) from the trash.
                          e.g.    trash -r file1 file2 ...
   -d, --dictionary   Display the dictionary of trashed files.
                      [Optional: Can include a text/regex filter]
                          e.g.    trash -r -d [text/regex]
 
-e, --empty           Permanently delete file(s)/folder(s) from the trash.
                          e.g.    trash -e file1 file2 ...
   --confirm          Empty the entire trash can.
                          e.g.    trash -e --confirm
   --older [days]     Delete only files older than the specified days.
                          e.g.    trash -e --older 30
 
-c, --cron            Manage automated trash emptying via cron.
   -p, --print        Display the current cron job related to trash.
                          e.g.    trash -c -p
   -t, --time [days]  Set up automatic emptying of trash every N days.
                          e.g.    trash -c -t 7
   -o, --older [days] Only delete files older than N days when emptying.
                          e.g.    trash -c -t 7 -o 30
```

## Usage Examples:

To move a file to the trash: `trash file1` or `ts file1`

To list all files in the trash: `trash -l` or `ts -l`

To recover a file: `trash --recover file1` or `ts -r file1`

To permanently delete a file from the trash: `trash --empty file1` or `ts -e file1`

To set up a cron job to empty trash every 30 days: `trash --cron --time 30`

To display help: `trash -h`

## Error Handling:

The script checks for the existence of files and directories before attempting operations.
It provides feedback if a file does not exist or if an unknown argument is provided.

## Dependencies:

* The tool requires Python 2.6.6 or newer to be installed for JSON operations.
* It uses standard Unix utilities like ls, mv, rm, and crontab.
