# Trash Tool (CLI Utility)
This tool is a Bash utility designed to manage files and directories by moving them to a designated "trash" directory, allowing for later recovery or permanent deletion. It mimics the recycle bin/trash functionality commonly found in graphical operating systems—but implemented for the command line. The current version is fully compliant with the [FreeDesktop.org](https://specifications.freedesktop.org/trash-spec/latest/) trash specification.

I came up with this idea when I was working on a highly restrictive Linux environment.

## Installation / Update
To install/update the tool, run the following command:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Maxsafer/trash-tool/refs/heads/freedtspec/installer.sh)"
```
* This installer creates a new folder called `trash_tool` (if it doesn’t already exist) and downloads `trash.sh` script.
* It sets up symlinks `ts` and `trash`, so that you can easily run the tool.
* Note: Running the installer multiple times will update the script without affecting previously trashed items. However, moving or renaming the installation folder will break the tool.

## Overview

### Freedesktop Compliance:
The tool uses the environment variable XDG_DATA_HOME (defaulting to $HOME/.local/share) to locate the trash directory ($XDG_DATA_HOME/Trash). Inside, it maintains the required files and info subdirectories, and creates a corresponding .trashinfo file for each trashed item containing its original path and deletion date in ISO8601 format.

### Conditional Unique Naming:
When a file or directory is trashed, the tool uses its original name unless a file with that name already exists in the trash. In case of a duplicate, a unique identifier is appended to ensure no naming collisions.

### Exact-Match Recovery with Collision Handling:
To recover an item, you must provide the exact trashed name. If you supply a base name and multiple trashed items share that base name, the tool will list the ambiguous options so you can specify which one to recover. If the original location is occupied, it applies collision handling and generates a new target name.

### Emptying Trash:
The tool supports three deletion modes:
* Entire Trash Deletion.
* Selective Deletion by Age.
* Individual Deletion.

### Cron Job Management:
The tool provides options for scheduling automatic trash emptying using cron, features:
* Can print the current cron job.
* Can set up a cron job to empty the trash every N days.
* Can limit deletion to items older than the specified number of days.

## Usage Examples
### Moving Items to Trash:
```
ts file1 file2
```
Moves the specified files or directories to trash.
#
### Listing Trashed Items:
* #### List all items:
```
ts -l
```
* #### Recursively list all files in the trash:
```
ts -l -R
```
* #### Select and list a specific trashed folder recursively:
```
ts -l -s folderName
```
* #### List with a filter (by text or regex):
```
ts -l [any option] filterText
```

### Recovering Items:
To recover a trashed item, provide the exact trashed name (which might include a unique identifier if there was a duplicate).
```
ts -r hello.txt-<uniqueID>
```
If you supply only a base name and multiple trashed items share that base name, the tool will ask you to specify the exact name.

### Emptying Trash:
* #### Delete a specific trashed item:
```
ts -e hello.txt-<uniqueID>
```
* #### Delete all items older than 30 days:
```
ts -e --older 30
```
* #### Empty the entire trash:
```
ts -e --confirm
```

### Cron Job Management:
* #### Display the current cron job for trash emptying:
```
ts -c -p
```
* #### Set up a cron job to empty the trash every 7 days:
```
ts -c -t 7
```
Note: This means that the cron job will execute on the 7th, 14th, 21th and 28th.
* #### Set up a cron job to empty the trash every 7 days, but only delete items older than 30 days:
```
ts -c -t 7 -o 30
```

### Help Menu:
```
ts -h
```
Displays detailed usage instructions. Running `ts` or `trash` are equivalent, and running them alone will also display help.
```
Trash Tool (freedesktop compliant v1.1)

Usage: ts [OPTION] [FILE]

Options:
  -h, --help           Show this help menu
  -l, --list           List trashed files
                        [Optional: -R/--Recursive for recursive listing]
                        [Optional: -s/--select for specific folder selection]
                        e.g.: ts -l, ts -l filter, ts -l -R, ts -l -R filter

  [no argument]        Move file(s)/folder(s) to trash
                        e.g.: ts file1 file2 ...

  -r, --recover        Recover file(s)/folder(s) from trash
                        (Specify the exact trashed file name; if only the base name is given
                         and multiple matches exist, the tool will print an ambiguous list.)
                        e.g.: ts -r hello.txt   or   ts -r hello.txt-<uniqueID>

  -e, --empty          Permanently delete file(s)/folder(s) from trash
       --confirm        Empty entire trash (requires confirmation)
       --older [days]   Delete only files older than the specified days
       [file names]    Delete the specified trashed file(s) individually

  -c, --cron           Manage automated trash emptying via cron
       -p, --print     Show current cron job
       -t, --time [days]   Set automatic emptying every N days
       -o, --older [days]  Only delete files older than N days when emptying
```

## Error Handling
* The tool checks for the existence of files or directories before attempting any operations.
* It prints clear error messages if a file doesn’t exist, if the provided arguments are ambiguous, or if a date can’t be parsed.
* OS-specific date parsing is implemented to work on both macOS and Linux without additional dependencies.

## Dependencies
* This tool uses standard Unix utilities such as ls, mv, rm, grep, and crontab.
* It works on both macOS and Linux without extra dependencies.

## Future Development
* Further refinements or additional features may be added in future releases.
* As always, feedback is welcome to improve compatibility or add new functionalities.
