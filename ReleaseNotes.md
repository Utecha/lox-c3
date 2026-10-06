# Release Notes

## Lox Version 0.0.2

- Added the `lox` and `lox::memory` modules.
- The VM now takes a pointer to a `LoxReallocFn` for handling the actual memory
allocation. This allows for it to be replaced with a different allocator
function.
