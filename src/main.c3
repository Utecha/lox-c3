module lox;
import std::io;

<*
    Ripped from 'read_file()', this simply allocates a (char *) and loads it
    with the characters from a separate string.

    NOTE: This DOES free the slice passed in for the user, but the user is expected
    to free the returned (char *).

    @param slice "The character slice to load into the char *"
*>
fn char *! string_to_charptr(char[] slice) @local
{
    char *string = (char *)malloc(slice.len + 1);
    for (usz i = 0; i < slice.len; i++)
        { string[i] = slice[i]; }

    string[slice.len] = '\0';
    free(slice);

    return string;
}

<*
    Read's in a *single* Lox source file into a (char *) buffer.

    The reason for this returning a (char *) and not a (String) is for the simple
    fact that it is actually easier to safely substring using pointer arithmetic
    than it is using array range indexing. It is also faster to deference a pointer
    than it is to index an array.

    @param filepath "The path to the source file to read"
    @ensure return != null
*>
fn char *! read_file(String filepath) @local
{
    char[]! slice = file::load_new(filepath);
    if (catch excuse = slice)
    {
        io::eprintf("Could not open file '%s'. Did you spell it right?", filepath);
        return excuse?;
    }

    return string_to_charptr(slice)!;
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

        String! line = io::readline();
        if (catch line)
        {
            io::print("\r");
            return;
        }

        char *! source = string_to_charptr(line);
        if (catch source)
        {
            io::print("\r");
            return;
        }

        if (!source) continue;
        if (catch vm::interpret(source))
        {
            free(source);
            continue;
        }

        free(source);
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
