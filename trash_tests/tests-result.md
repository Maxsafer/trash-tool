# Last test results:
```
trash_tests.bats
 ✓ Check trash tool path
 ✓ Check trash directory exists
 ✓ Recover file from trash
 ✓ Move file to trash
 ✗ List with regex filter
   (in test file trash_tests.bats, line 66)
     `[ "$status" -eq 0 ]' failed
 ✓ Recursive listing
 ✓ Select specific folder
 ✓ Empty trash older than N days
 ✓ Multiple file trash
 ✓ Empty specific file from trash
 ✓ Multiple file emptying
 ✓ File collision handling
 ✓ Directory collision with nested structure
 ✓ Nested directory recovery with collisions
 ✓ Multiple directory level collisions
 ✓ Handle special characters in filenames
 ✓ Handle unicode characters in filenames
 ✓ Handle file with no read permission
 ✓ Handle file with no write permission

19 tests, 1 failure

```

## I have no clue why that test fails, manual execution succeeds:
```
# ts -l
Trashed-Files    Trashed-Date       Original-Path
# touch reg1.txt
# touch reg2.txt
# ts reg1.txt reg2.txt
Moved to trash: reg1.txt
Moved to trash: reg2.txt
# ts -l reg1
reg1.txt      2025-02-27T04:52:57    /root/reg1.txt
```
