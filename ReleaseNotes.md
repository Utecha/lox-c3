# Release Notes

## Lox Version 0.0.2

- Added the `lox` and `lox::memory` modules.
- The VM now takes a pointer to a `LoxReallocFn` for handling the actual memory
allocation. This allows for it to be replaced with a different allocator
function.
- Add custom `next_power_of_two` macro to remove the need to import `std::math`
in several places just for that macro.
- Added `lox::array` generic module for generically typed dynamic arrays managed
by the VM's allocator.
