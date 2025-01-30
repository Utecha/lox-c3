- [0.1.1](#011)
- [0.1.1-1](#011-1)

### 0.1.1

Everything has pretty much been rewritten. One of C3's updates made changes to how enums work which broke
the code. It wouldn't have been to difficult to switch to the new system, but I needed an excuse to get to
work on the continuation of this project so I chose to take that opportunity to start over.

The language has regressed to a large degree, as I have only successfully reimplemented up to if statements
and loops. I have had several issues with getting functions reimplemented. That's likely going to take
a significant refactor/partial rewrite of the compiler and VM to make happen.

Below is a list of changes introduced thus far:

- Added block style comments.
- Semicolons are now statements by themselves, like in C.
- Added color to a lot of the terminal output.
- Improved error messages, including now reporting the filename.
This is, in part, preparation for *eventually* adding a module system.

- Moved and updated the code from `test/tests.c3` for the Lexer into the debug module.
- ***AND*** can now be expressed as `and` or `&&`.
- Likewise, ***OR*** can now be expressed as `or` or `||`.
- Keeping with the theme, `not` was added as a keyword, completing the set.
- Updated the REPL and verified both compilation and successful execution on Windows.
    - To build for windows: run `c3c build lox-windows` or `c3c run lox-windows` to build/run.
    - For POSIX compliant OS's, you only need to run `c3c build` or `c3c run`
- Updated .gitignore.
- Version displayed in the REPL is now pulled directly from the `project.json`.

### 0.1.1-1

Finished the initial refactor. The only real change, per-se, for this update is the addition
of the modulo operator (and of course the refactor, but that doesn't really affect much for
the end user).

I also removed the `NOT` token as it was redudant, and switched the negate operator to
a slightly more optimized variant. Ideally, along with functions returning, next update should
also include bitwise and bitshift operators.