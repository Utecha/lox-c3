module lox;
import std::io;

//===----------------------------------------------------------------------===//
// Lox | Main
//===----------------------------------------------------------------------===//

/* Read's a single source file into a (char *) buffer and returns it */
/* NOTE: This is left public for the sake of the unit tests that depend on it */
fn char *! read_file(String filename)
{
    char[]! src_slice = file::load_new(filename);
    if (catch excuse = src_slice)
    {
        io::eprintf("Could not open file '%s'. Did you spell it right?", filename);
        return excuse?;
    }

    char *source = (char *)malloc(src_slice.len + 1);
    for (usz i = 0; i < src_slice.len; i++)
        { source[i] = src_slice[i]; }
    source[src_slice.len] = '\0';

    free(src_slice);
    return source;
}

/* Runs a single source file through the VM interpreter */
fn void! run_file(String filename) @private
{
    char *source = read_file(filename)!;
    defer free(source);
    vm::interpret(source)!;
}

/* VERY simple REPL */
fn void! repl() @private
{
    for (;;)
    {
        io::print(">>> ");

        String! line = io::readline();
        if (catch line)
        {
            io::printn();
            return;
        }

        vm::interpret(line)!;
        free(line);
    }
}

/* Entry Point */
fn void! main(String[] args)
{
    vm::init();
    defer vm::free();

    switch (args.len)
    {
        case 1:
            repl()!;
        case 2:
            run_file(args[1])!;
        default:
            io::eprintfn("Usage: lox [script]");
            return LoxError.USAGE?;
    }
}