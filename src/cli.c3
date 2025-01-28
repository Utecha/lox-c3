module lox::cli;
import lox::vm;
import std::io;

//------------------------------------------------------------------------------
// Lox \ CLI -- File IO
//------------------------------------------------------------------------------

fn char *readFile(String path)
{
    File! file = file::open(path, "rb");
    if (catch file)
    {
        elog("Could not open file '%s'. Did you spell it right?", path);
        return null;
    }
    defer (void) file.close();

    usz size = file.seek(0, Seek.END)!!;
    file.seek(0, Seek.SET)!!;

    char *buffer = (char *)malloc(size + 1);
    if (!buffer)
    {
        elog("Not enough memory to read '%s'.", path);
        return null;
    }

    usz! numBytes = file.read(buffer[:size]);
    if (catch numBytes)
    {
        elog("Could not read file '%s'.", path);
        return null;
    }
    buffer[numBytes] = '\0';

    return buffer;
}

fn int runFile(LoxVM *vm, String path)
{
    char *source = readFile(path);
    if (!source) return 65;
    defer free(source);

    return vm.interpret(source).ordinal;
}

//------------------------------------------------------------------------------
// Lox \ CLI -- REPL
//------------------------------------------------------------------------------

extern fn char *readline(char *prompt) @if(!env::WIN32);
extern fn void add_history(char *input) @if(!env::WIN32);

/* Fake readline function */
fn char *readline(char *prompt) @if(env::WIN32)
{
    io::print(prompt);

    String! str = io::readline();
    if (catch str) return null;
    defer str.free();

    return str.zstr_copy();
}

/* Fake add history function */

fn void add_history(char *input) @if(env::WIN32) { return; }

fn void repl(LoxVM *vm)
{
    $if $feature(DEBUG):
        io::printn("LoxVM REPL Version 0.1.0 [ DEBUG MODE ]");
    $else
        io::printn("LoxVM REPL Version 0.1.0");
    $endif
    io::printn("Press Ctrl-D to exit.\n");

    for (;;)
    {
        char *line = readline(">>> ");
        if (!line)
        {
            io::printn();
            return;
        }

        add_history(line);
        vm.interpret(line);
        free(line);
    }
}
