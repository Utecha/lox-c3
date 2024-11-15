# Release Notes -- Pre-Version 0.1.0

- Build [0.0.1](#release-001)
- Build [0.0.2](#release-002)
- Build [0.0.3](#release-003)

## Build 0.0.1

This build is in line with [Chapter 14](https://craftinginterpreters.com/chunks-of-bytecode.html#top) of the book.

## Build 0.0.2

This build is in line with [Chapter 15](https://craftinginterpreters.com/a-virtual-machine.html#top) of the book.

In addition:

- Added the modulus operator.
- Everything is now documented with either a regular or C3 doc comment (which includes compile-time check features)
- Implemented the optimized negation operator from the challenges section.
- Added a misc. flag for enabling/disabling the optimized negation operator (for testing/learning purposes).

## Build 0.0.3

This build is in line with [Chapter 16](https://craftinginterpreters.com/scanning-on-demand.html#top) of the book.

No special additions to the language that the original didn't have.

The only differences are in how I make tokens, how I match keywords, and how I retrieve characters in lexer functions like ```advance()```.

The body of ```advance()```, in the original, looks something like this:

```c
scanner.current++;
return scanner.current[-1];
```

The body in lox-c3 looks like this:

```c
lexer.current++;
return *(lexer.current - 1);
```

They do the exact same thing, except one uses pointer dereferencing in place of array indexing. This is mostly because its a little bit faster.

NOTE: There is no difference here between 'scanner' and 'lexer' other than the words themselves. They mean the same thing. C3 has a built-in 'Scanner' struct that conflicts, plus I just prefer 'Lexer' so I changed it.

Keywords are matched by taking advantage of C3's ```String``` type, which can be directly compared with something like the ```==``` operator (which is implicitly done by a switch statement).

On that note, while the Lexer works with ```char *```, it generates tokens whose lexeme is of the type ```String```. That has a number of advantages including making it simpler to pass in to print functions (such as for error reporting), and having a built-in ```len``` property.
