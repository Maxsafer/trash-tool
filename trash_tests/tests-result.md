# Last test results:
```
trash_tests % sh runtests.sh 
trash_tests.bats
 ✓ Check trash_tool path
 ✓ List trash_can directory
 ✓ Check trash.json file
 ✓ Recover file from trash
 ✓ Move file to trash
 ✓ List with regex filter
 ✓ Recursive listing
 ✓ Select specific folder
 ✓ Empty trash older than N days
 ✓ Multiple file trash
 ✓ Empty file from trash
 ✓ Multiple file emptying
 ✓ File collision handling
 ✓ Directory collision with nested structure
 ✓ Nested directory recovery with collisions
 ✓ Multiple directory level collisions
 ✓ Handle special characters in filenames
 ✓ Handle unicode characters in filenames
 ✓ Handle file with no read permission
 ✓ Handle file with no write permission
 ✓ Handle corrupted JSON file
 ✓ Simulate corrupted JSON by removing last curly bracket
 ✓ Simulate corrupted JSON by deleting a chunk
 ✓ Handle empty JSON file

24 tests, 0 failures
```
