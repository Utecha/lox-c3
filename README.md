# Lox Programming Language - C3 Edition

This repo contains a variation on the [Lox](https://craftinginterpreters.com/) programming language by [Robert Nystrom](https://journal.stuffwithstuff.com/).

This project is an extended version of 'clox', the bytecode VM variant originally written in C, now written in the C3 language. I also dropped the prefix. It is invoked using ```lox```.

## Build

To build this project, you must first install the [C3 language](https://c3-lang.org/).

To build for release:

```sh
c3c build
```

To build for debug:

```sh
c3c build -D DEBUG
```

You can also run those same commands, replacing ```build``` with ```run``` to immediately run the application after the fact. The compiler has a simple built-in REPL for playing around with the language. It can also accept a *single* source file as input.

## License

This project is licensed under the MIT License.