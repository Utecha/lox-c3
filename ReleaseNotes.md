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

### 0.2.0

This was a big jump. Basically everything I did in the previous 2 releases was thrown out. I hadn't touched the project in a little bit and after coming back to it,
I was ultimately unhappy with how it was going. I chose to go back to keeping Lox relatively 'vanilla', as in I didn't really add any new language features. All of the
changes are underneath the hood.

Some notable differences between v0.2.0 and v0.1.0:

- Chunks now use type aliases of a newly defined generic buffer type for its fields. Later, chunks will be removed entirely and all aspects of it integrated into the
compiler and inlined in ObjFns.
- No more global VM, Compiler, etc. Well, the compiler does have 1 global to help keep track of the current class (if applicable). Aside from that, everything from
the lexer all the way up to the VM is passed through functions (or methods) by pointer.
- NaN Tagging actually works now. If I remember correctly, 0.1.0 had broken NaN Tagging and I was unsure why. It doesn't seem to provide much of an improvement in
performance, but in all fairness without arrays being added to the language in some form, it would be difficult to write a real world program large enough for
you to notice a real difference.

Those are the only major changes as of now. Some things that I had initially added in previous updates that were removed will be readded, plus some. This includes
new operators such as the Modulo (%) operator. I would like to potentially work in the idea of implementing a sort of int type like in Wren. This would potentially
allow for Bitwise operations to be implementable. Bitwise operators cannot work directly with floating-point values, so something of that nature would have to occur
before they can be added. I also plan to add 'break' and 'continue' as keywords, and bring back the ternary operator (?:). Finally, I would like to try my hand
at implementing a builtin Array/List, Map, and switch/match statements. For "extra credit", I am considering trying to implement Enums as well as the '++/--' operators
in their full glory. The '++/--' operators are a lot tougher to implement correctly than it seems on the surface (I have attempted it before so I speak from experience).
Getting the postfix variants implemented isn't too bad, but getting both it and the prefix variants together is a different beast.
