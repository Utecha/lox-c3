# Release Notes

These release notes will end at the completion of version [0.1.0](). Version [0.1.0]() and earlier are more directly based on the original implementation of 'clox'.

See the original implementations [here](https://github.com/munificent/craftinginterpreters) as well as my own written implementations of 'clox' and 'jlox' [here](#ADDLATER).

Versions [0.1.1]() and beyond will have their own release notes as it will be an entirely rewritten implementation
complete with further optimizations, more features, design changes (syntax and structure) and more.

## Index

- Release [0.0.1](<release_notes_v010#Release 0.0.1>)
- Release [0.0.11](<release_notes_v010#Release 0.0.11>)

## Release 0.0.1

This release is in line with [Chapter 14](https://craftinginterpreters.com/chunks-of-bytecode.html#top) of the book.

## Release 0.0.11

Along with the original implementation are the completion of the challenges for run-length encoded line information, and the CONSTANT_LONG instruction.

Other updates:
- Updated README to remove mention of the 'DEBUG' feature flag. That does not apply to to Version [0.1.0] and under.
- Likewise, I updated the project.json to reflect that the above change.
- Added the first unit test. Also added folders to begin organizing the unit tests as well as the test source files.

## Release 0.0.2

This release is in line with [Chapter 15](https://craftinginterpreters.com/a-virtual-machine.html#top) of the book.

- Added the virtual machine.
- Moved the ```to_byte()``` and ```to_code()``` macros into ```common.c3``` as builtins.
- Added the first debug flag 'TRACE_INSTRUCTIONS'. Set to true to enable stack tracing.
- Added 5 new instructions: NEGATE, ADD, SUBTRACT, MULTIPLY, DIVIDE.
- Fixed the function naming conventions for the functions/methods in ```debug.c3```.
- The ```main()``` function now returns ```void!``` rather than ```int```.
- Completed the challenge to optimize the NEGATE instruction.

#### NOTE: The CONSTANT_LONG instruction will not be supported properly within the VM until the concept of call frames are implemented.