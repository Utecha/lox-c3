module lox;
import std::io;

<*
    Read's in a *single* Lox source file into a (char *) buffer.

    The reason for this returning a (char *) and not a (String) is for the simple
    fact that it is actually easier to safely substring using pointer arithmetic
    than it is using array range indexing. It is also faster to deference a pointer
    than it is to index an array.

    @param filepath "The path to the source file to read"
    @ensure source != null
*>
fn char *! read_file(String filepath) @local
{
    char[]! slice = file::load_new(filepath);
    if (catch excuse = slice)
    {
        io::eprintf("Could not open file '%s'. Did you spell it right?", filepath);
        return excuse?;
    }

    char *source = (char *)malloc(slice.len + 1);
    for (usz i = 0; i < slice.len; i++)
        { source[i] = slice[i]; }

    source[slice.len] = '\0';
    free(slice);

    return source;
}

<*
    Executes a *single* Lox source file.

    @param filepath "The path to the source file to read"
*>
fn void! run_file(String filepath) @local
{
    char *source = read_file(filepath)!;
    defer free(source);

    vm::interpret(source)!;
}

// NOTE: This will be removed and replaced later with at least a mildly more sophisticated
// version, at least for POSIX compliant systems. Windows will be stuck with this.
<*
    Very simple REPL for the Lox Virtual Machine.
*>
fn void repl() @local
{
    for (;;)
    {
        io::print(">>> ");

        String! source = io::treadline();
        if (catch source)
        {
            io::print("\r");
            return;
        }

        if (catch vm::interpret(source)) continue;
    }
}

//===----------------===//
//     Entry Point
//===----------------===//

fn void! main(String[] args)
{
    vm::init();
    defer vm::free();

    switch (args.len)
    {
        case 1:
            repl();
        case 2:
            run_file(args[1])!;
        default:
            io::eprintf("Usage: lox [script]");
    }
}
