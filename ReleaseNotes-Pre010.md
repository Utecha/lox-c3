# Release Notes -- Pre-Version 0.1.0

- [Build 0.0.1](#build-0-0-1)
- [Build 0.0.2](#build-0-0-2)
- [Build 0.0.3](#build-0-0-3)
- [Build 0.0.4](#build-0-0-4)
- [Build 0.0.45](#build-0-0-45)
- [Build 0.0.5](#build-0-0-5)
- [Build 0.0.55](#build-0-0-55)
- [Build 0.0.6](#build-0-0-6)
- [Build 0.0.65](#build-0-0-65)

## Build 0-0-1

This build is in line with [Chapter 14](https://craftinginterpreters.com/chunks-of-bytecode.html#top) of the book.

## Build 0-0-2

This build is in line with [Chapter 15](https://craftinginterpreters.com/a-virtual-machine.html#top) of the book.

In addition:

- Added the modulus operator.
- Everything is now documented with either a regular or C3 doc comment (which includes compile-time check features)
- Implemented the optimized negation operator from the challenges section.
- Added a misc. flag for enabling/disabling the optimized negation operator (for testing/learning purposes).

## Build 0-0-3

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

## Build 0-0-4

This build is in line with [Chapter 17](https://craftinginterpreters.com/compiling-expressions.html#top) of the book.

- Added new tokens for ```?``` and ```:```.
- Added the ternary operator (does not properly interpret yet, that comes next chapter with the introduction of 'falsiness').
- Removed the ```@private``` attribute on ```Chunk.write()``` and removed all of the wrapper functions.
- Replaced the above point with a couple of macros that simple convert back and forth between ```char``` and ```OpCode```.
- Added separate ```error.c3``` module for the error reporting functions.

At this point you have a functioning compilation pipeline, though the language is nothing more than a glorified calculator, capable of all of the basic operations (+, -, *, /, %).

## Build 0-0-45

This build is in line with [Chapter 18](https://craftinginterpreters.com/types-of-values.html#top) of the book.

- Fixed bug causing the compiler to still pass on to the VM despite having the 'DEBUG' feature AND 'DUMP_TOKENS' enabled.
- Fixed a bug causing the VM to die to a null pointer dereference if you entered an empty line into the REPL.

The only *real* difference between this and the original is the ternary operator. I implemented about 90% of it last chapter, however the machinery it needed was going to be
added in this chapter with the introduction of dynamic typing and more types. It is now fully enabled and working.

I did add another flag to ```common.c3``` for enabling/disabling the optimization on the NOT (!) operator. It is able to take on the exact same optimization that the NEGATE (-) operator does.

There may be a time when this is condensed into one flag called 'OPTIMIZE_STACK' or something of that nature. It would be a generic flag that enables/disables all stack-based optimizations.

Not related to the project necessarily, I modified this file to change the version numbers from "0.0.1" to "0-0-1", as an example. This is in an effort to (hopefully) get the index links at the top to actually *work*. According to my markdown linter and preview, it does indeed fix the problem.

## Build 0-0-5

This build is in line with [Chapter 19](https://craftinginterpreters.com/strings.html#top) of the book.

- Added doc comments to the few places where I forgot them.
- Re-fixed the null-pointer dereference when entering an empty line into the REPL (see below).

Apparently in one of the recent revisions of C3, the ```char[]``` (also known as a character slice) was made to be able to implicitly cast into a ```char *```. As a result,
some of the machinery I added to safely convert from one to the other was unnecessary. I have removed that code, and the fix for the null-pointer dereference is now a simple
check at the start of the VM's ```interpret()``` function for the source being passed in as 'null'.

This chapter adds objects, and the first object of which is the string type. All Objects in Lox are Values (but not all Values are Objects). Examples of Objects include strings, functions, classes, instances, etc (most of which comes later).

## Build 0-0-55

This build is in line with [Chapter 20](https://craftinginterpreters.com/hash-tables.html#top) of the book.

Implemented the backend hash table for the language. Strings are now interned and as a result, comparison equality of strings is faster.

## Build 0-0-6

This build is in line with [Chapter 21](https://craftinginterpreters.com/global-variables.html#top) of the book.

- Lox now supports global variable declarations, assignment, and use in expressions/statements.
- Further to that, Lox now supports statements in general. You're now required to end lines with a ';'.

## Build 0-0-65

This build is in line with [Chapter 22](https://craftinginterpreters.com/local-variables.html#top) of the book.

This chapter added local variables and the concept of scope to the mix.

This means, subsequently, that blocks were introduced. You can now write arbitrary block statements (any number of statements enclosed in {}).

Information is retained about the depth of scope. Shadowing is allowed, which means you can have 2 variables with the same name in *different* scopes.

It is an error to declare 2 variables with the same name in the *same* scope.

##### NOTE: For now, I have decided to abandon the idea of using GNU readline for an improved REPL. I may well end up writing my own similar library specifically for C3 and saving it for a post '0.1.0' release
