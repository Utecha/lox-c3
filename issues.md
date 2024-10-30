# Known Issues

### Line Information Debugging

There *WAS* a bug when it came to the line information coming from disassembly. I managed to find the bug and squash it, though.

It was in the Chunk.get_line() method. Simply changing the line ```end = mid - 1;``` to ```end = mid;``` fixed it.