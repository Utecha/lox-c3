# Lox - C3 Edition

This repo contains my implementation of the [Lox](#lox) programming language.

This is based on the bytecode virtual machine originally written in C,
but now in [C3](#c3).

I'm currently in the middle of rewriting it for the latest version of C3.
This is partially because there were significant changes in the language,
and it also gives me the opportunity to pull some internal features of
the [Wren](#wren) language downstream into Lox.

I'm not currently building release binaries until the project has been fully
rewritten. To try it out, you must build it from source. Thankfully, doing
so is *extremely* easy.

## Building from source

To build this project from source, you must first install [C3](#c3-bin).
The minimum version should be `0.8.4`.

Before proceeding, ensure that `c3c` is installed and available in your PATH!

Then, run this command from within the repo:

```sh
c3c build release
```

This will compile the release version of the executable, which can then be
found at `build/Release/lox`.

Conversely, you can immediately run it using this command:

```sh
c3c run release
```

If you used the 'build' option, you can then directly run lox from the 'build'
directory. Running it by itself will invoke the REPL. You can optionally add a
filepath as an argument to run a script at that path.

```sh
./build/Release/lox [file]
```

If you use the 'run' option, you can optionally add a '--' and then the path to
a script. The C3 compiler will pass that argument to the executable before
running it.

```sh
c3c run release -- [file]
```

If you want to mess around with the built-in debugger, replace `release` with `debug` to
build the debug version of the executable.

Before doing so, open up the `debug.c3` file and edit the debugging flags (constants) at
the top to control the type of debugging output you receive.

#### NOTE: Lox does not have a module system, and only supports running a single script.

[lox]: https://craftinginterpreters.com/
[c3]: https://c3-lang.org
[c3-bin]: https://github.com/c3lang/c3c/releases/tag/v0.8.4
[wren]: https://wren.io/
