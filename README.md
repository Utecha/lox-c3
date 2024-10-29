# Lox Programming Language - C3 Edition

This repo contains a variation on the [Lox](https://craftinginterpreters.com/) programming language by [Robert Nystrom](https://journal.stuffwithstuff.com/).

This project is an extended version of 'clox', the bytecode VM variant originally written in C, now written in the C3 language. I also dropped the prefix. It is invoked using ```lox```.

## Notes

Versions [0.1.0] and earlier are all faithful "extended" implementations of 'clox' as written in the book, minus some C3-isms. The release notes can be found [here](#ADDLATER).

Versions [0.1.1] and onward will be a complete reimplementation of the language with further optimizations, more features and even some design changes (different syntax and the like). It will also take advantage of more of C3's
features.

## Build

To build this project, you must first install the [C3 language](https://c3-lang.org/).

To build, run:

```sh
c3c build
```

You can also run these same command, replacing ```build``` with ```run``` to immediately run the application after the fact.

The compiler has a simple built-in REPL for playing around with the language. It can also accept a *single* source file as input.

## License

This project is licensed under the MIT License.