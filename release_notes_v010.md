# Release Notes

These release notes will end at the completion of version [0.1.0](). Version [0.1.0]() and earlier are more directly based on the original implementation of 'clox'.

See the original implementations [here](https://github.com/munificent/craftinginterpreters) as well as my own written implementations of 'clox' and 'jlox' [here](#ADDLATER).

Versions [0.1.1]() and beyond will have their own release notes as it will be an entirely rewritten implementation
complete with further optimizations, more features, design changes (syntax and structure) and more.

## Index

- Release [0.0.1](<release_notes_v010#Release 0.0.1>)
- Release [0.0.11](<release_notes_v010#Release 0.0.11>)
- Release [0.0.2](<release_notes_v010#Release 0.0.2>)
- Release [0.0.25](<release_notes_v010#Release 0.0.25>)
- Release [0.0.3](<release_notes_v010#Release 0.0.3>)
- Release [0.0.35](<release_notes_v010#Release 0.0.35>)
- Release [0.0.4](<release_notes_v010#Release 0.0.4>)
- Release [0.0.45](<release_notes_v010#Release 0.0.45>)

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

#### NOTE: The CONSTANT_LONG instruction will not be supported properly within the VM until the concept of call frames are implemented

## Release 0.0.25

This release is in line with [Chapter 16](https://craftinginterpreters.com/scanning-on-demand.html#top) of the book.

- Added the ```compile()``` function which is the preamble to the compiler.
- Added the lexer for the language.
- Added a simple REPL and function to load a source file, which pass off their inputs to the VM.
- The interpreter is currently disconnected until the compiler is added. For now, ```interpret()``` runs the compiler which just lexes the source and dumps the tokens to stdout.
- Renamed the ```constant_long.c3``` unit test to ```chunk.c3``` as it will contain all chunk-related unit tests.
- Added ```lexer.c3``` to the unit tests. It lexes and dumps the test source files located in ```test/lexer/```.

## Release 0.0.3

This release is in line with [Chapter 17](https://craftinginterpreters.com/compiling-expressions.html#top) of the book.

- Implemented the compiler, completing the entire pipeline (from source to interpretation).
- Temporarily bumped the capacity of the VM stack to 512 in order to support up to 256 CONSTANT_LONG instructions (512 total instructions loaded at once).
- With the above in mind, CONSTANT_LONG's are fully supported even through interpretation.
- Currently supports numbers, basic arithmetic binary operators, and the negation operator.
- Fixed the REPL so that it no longer yeets you out on error.
- Exiting of the REPL now outputs a single carriage return, rather than a newline. This makes the exit look a little cleaner.
- Basic support in the compiler for the ternary (?:) operator. Without jumping too far ahead, I don't have the necessary functionality to support it all the way through interpretation. Despite that, it will run without producing an error, and the VM simply returns the result of the last expression pushed onto the stack, which is the 'false' branch.
- Some minor function renaming in the unit tests, as well as a new unit test for the VM.
- Added ```issues.md``` to document known bugs and other issues.

## Release 0.0.35

This release is in line with [Chapter 18](https://craftinginterpreters.com/types-of-values.html#top) of the book.

- The dynamic typing system has been expanded to include more types: boolean and nil.
- Added support for equality and comparison operators (==, !=, >, >=, <, <=).
- Finished support for the ternary operator. It should now work as you'd expect.
- Introduced the concept of falsiness (or truthiness?). false and nil are falsey, everything else is truthy.

The language is starting to become a little bit more useful now. It is still missing strings, functions, classes, etc. at this point but it is now possible to compute logic and not just arithmetic.

## Release 0.0.4

This release is in line with [Chapter 19](https://craftinginterpreters.com/strings.html#top) of the book.

- The concept of objects exist within the internals of the compiler. They are used to represent heap-allocated structures.
- Strings have been added to the language.
- Fixed some small typos and such in this file and others.
- Updated ```chunk.c3``` in the unit tests to reflect the changes to the 'Value' type.

The implementation of strings are not the most efficient, but they work. They will be a bit more memory efficient when hash tables are introduced in the next chapter (and as a result, string interning).

## Release 0.0.45

This release is in line with [Chapter 20](https://craftinginterpreters.com/hash-tables.html#top) of the book.

- Fixed a small bug.. and by small, I mean a big one known as a memory leak. I added the ability to free all of the (Obj) pointers, however I never actually *called* it inside of the VM's ```free()``` function. That is fixed now.
- Added a hash table. It is only really used internally to intern every string, at the moment.

There are some benefits to interning every string:
  1. Direct equality comparison using the ```==``` operator, which is faster than before.
  2. Deduplication of strings which saves a bit of memory and *could* speed up lookup as a result.
  3. Probably more but I'm no CS major.

#### NOTE
I preemptively implemented an optimization that appears in the, well, Optimizations chapter of the book. That optimization is for the formula that retrieves the index inside of methods like ```Table.find()```. At this point in the book, the formula should look something like this:

```c
uint index = hash % capacity;

// Then later...
index = (index + 1) % capacity;
```

For whatever reason, at least in my earlier attempts at this (don't ask), C3 really was not happy with the original implementation and the tables would break (I can't remember exactly how because its been a little bit...). The fix, oddly enough, was to implement the optimization. That looks like this:

```c
uint index = hash & (capacity - 1);

// Then later...
index = (index + 1) & (capacity - 1);
```

This uses bitwise-and as a faster replacement for the modulo operator. Why it had issues with the actual modulo, I cannot tell you. This is faster anyways, so who really cares, right?