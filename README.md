# Lox - C3 Edition

This is an implementation of the [Lox](https://craftinginterpreters.com/) programming language.

This is based on the bytecode virtual machine variant originally written in C, but now in [C3](https://c3-lang.org).

You can find the release binary on the releases page, or build it from source.

## Building from source

To build this project from source, you must first install [C3](https://github.com/c3lang/c3c/releases/download/latest/c3-linux.tar.gz).

It requires at least version [0.6.4](https://github.com/c3lang/c3c/releases/tag/v0.6.4) or later.

Make sure to add it to your PATH!

Then, run this command from within the repo:

```sh
c3c build
```

Conversely, you can directly run it using:

```sh
c3c run
```

I included a ```DEBUG``` feature flag that enables the built-in debugger. To enable this, add ```-D DEBUG``` to the end of either of the above commands.

In addition to the feature flag, you must edit the ```src/common.c3``` to enable or disable the specific debugging features.

#### NOTE: Running those commands by themselves can be used to build/run the application directly. Simply invoking the compiler will run it in REPL mode. You can optionally
pass a file to it as an argument, and it will attempt to compile and run that file.

If you used the 'build' option, you can then directly run lox from the 'build' directory, with the location of a file as an argument.

```sh
./build/lox <source file>
```

If you used the 'run' option, you can optionally add a '--' and then the location of a file, and c3c will pass that argument on to lox and run the specified file.

```sh
c3c run -- <source file>
```

#### NOTE: Lox is designed to only run one source file at a time. There is no module system in which to work with. Passing multiple files is an error.
