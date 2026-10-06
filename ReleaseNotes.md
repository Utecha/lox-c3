# Release Notes

The goal of the latest rewrite of the project is not only to continue having the
project work with current versions of the C3 compiler. It is also to bring down
some features and improvements from the Wren language.

It will still be Lox in the end, however certain internal functions and data
structures will be different from the original implementation for one reason
or another.

## Lox Version 0.0.2

- Added the `lox` and `lox::memory` modules.
- Added the `LoxConfig` type to the `lox` module. This will contain
configuration data and function pointers for the VM to make use of.
- The VM's config takes a pointer to a `LoxReallocFn` for handling the actual
allocation of memory. This allows for it to be replaced with a different allocator
function.
- Added a custom `next_power_of_two` macro to remove the need to import
`std::math` in several places just for that macro.
- Added the `lox::array` generic module for generically typed dynamic arrays
managed by the VM's allocator.
- Added the `lox::value` module. Jumped ahead and implemented the NaN boxed
variant of the `Value` type, as well as the early start of objects as the
`Chunk` has been removed and inlined into the `ObjFun` type.
- Added the `lox::opcode` module which defines all of the supported
operation codes.
- Added the `lox::debug` module.

The totality of this initial build is effectively the first chapter of the book
plus a few addons/modifications to the original implementation.
