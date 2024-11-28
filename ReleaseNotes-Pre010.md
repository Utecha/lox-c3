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
- [Build 0.0.7](#build-0-0-7)
- [Build 0.0.75](#build-0-0-75)
- [Build 0.0.8](#build-0-0-8)
- [Build 0.0.85](#build-0-0-85)
- [Build 0.0.9](#build-0-0-9)
- [Build 0.0.95](#build-0-0-95)
- [Build 0.0.99](#build-0-0-99)

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

## Build 0-0-7

This build is in line with [Chapter 23](https://craftinginterpreters.com/jumping-back-and-forth.html#top) of the book.

This chapter adds jumping instructions. This includes 'and' and 'or' expressions, 'if' statements, and the 'for' and 'while' loops.

At this point, the language is *relatively* usable (emphasis on *relatively*!!). There are glaring issues that prevent it from being legitimately useful as a language, though. A big example of this are strings. Strings in Lox are *ALL* raw strings. There is no support for escape characters, or for string formatting. That alone significantly limits the capabilities of a language.

My plans for the post '0.1.0' rewrite will include support for both raw strings, and format-capable (aka escaped) strings.

Soon to come in the next few builds are functions, closures, and the venerable *garbage collector* (respectively).

## Build 0-0-75

This build is in line with [Chapter 24](https://craftinginterpreters.com/calls-and-functions.html#top) of the book.

This chapter added functions in all of their glory. This, of course, means the ability to define functions and then call to those functions.

As you'd expect, functions implicitly return null, but that can also be done explicitly. They can also return values.

Functions are also capable of recursion. A function can refer to and call itself from within its own body.

Furthermore, there is the inclusion of 'native' functions. These are functions written in native C3 code. The VM maintains an array of pointers to the native functions added to the language, making them available to be called from within Lox code.

In the original book, the only native function added to the language was a 'clock' function that you would use to effectively create a timer for a program like so:

```javascript
var start = clock();
thisFunctionDoesSomething();
print clock() - start;
```

This would display the amount of time (in seconds) that the code in-between the two calls to 'clock' took to execute.

I have little desire to really add any more than that one at this point. Ideally, I'd want to set it up so that natives (and user functions, for that matter) can be variadic. That is all things I will be working on post '0.1.0'.

Speaking of which, it's probably time that I mention.. Post 0.1.0 will actually be under a different name and have its own separate repo altogether. I will add that repo as a submodule of this one so it
wont be difficult to find.

## Build 0-0-8

This build is in line with [Chapter 26](https://craftinginterpreters.com/closures.html#top) of the book.

This chapter added closures, and the concept of upvalues (shoutout to Lua). An upvalue is a local variable that is referenced within an enclosed function, that would otherwise no longer be on the VMs stack. The local is then captured, and "closed" which hoists it onto the heap, making it still accessible.

Closures effectively allow functions to be defined within functions. For example:

```java
fun outer() {
    var outside = "outside";

    fun inner() {
        print outside;
    }

    return inner;
}

var closure = outer();
print closure();    // Prints 'outside'
```

The next build introduces the garbage collector to the language. Afterwards come classes, instances, and methods. Then, optimizations.

## Build 0-0-85

This build is in line with [Chapter 26](https://craftinginterpreters.com/garbage-collection.html#top) of the book.

Fully implemented the mark-sweep style garbage collector.

## Build 0-0-9

This build is in line with [Chapter 27](https://craftinginterpreters.com/classes-and-instances.html#top) of the book.

This build introduces classes and instances.

Currently, there is no ability to define methods. That comes in the next build.

After that will come *single* inheritance.

## Build 0-0-95

This build is in line with [Chapter 28](https://craftinginterpreters.com/methods-and-initializers.html#top) of the book.

As of this build, classes and methods have been fully implemented, with the exception of inheritance.

Example:

```javascript
class Person {
    init(name, age, height, weight) {
        this.name = name;
        this.age = age;
        this.height = height;
        this.weight = weight;
    }

    info() {
        print this.name;
        print this.age;
        print this.height;
        print this.weight;
    }
}

var person = Person("George", 34, 72, 160);
person.info();
```

#### Known Issues

As of this chapter, I discovered a bug that comes up occasionally when errors occur, causing the compiler to hang.

I'm not currently sure of the cause. I will look into this before I tackle inheritance and optimization.

## Build 0-0-99

This build is in line with [Chapter 29](https://craftinginterpreters.com/superclasses.html#top) of the book.

This chapter added inheritance and superclasses. The final chapter is optimization. The completion of that will be a proper release version 0.1.0.