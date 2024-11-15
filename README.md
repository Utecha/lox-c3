# Lox - C3 Edition

This is an implementation of the [Lox](https://craftinginterpreters.com/) programming language.

This is based on the bytecode virtual machine variant originally written in C, but now in [C3](https://c3-lang.org).

To build this project, you must first [download](https://github.com/c3lang/c3c/releases/download/latest/c3-linux.tar.gz) the C3 language.

It requires at least version [0.6.4](https://github.com/c3lang/c3c/releases/tag/v0.6.4) or later.

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
