import lox;
import std::io;

//------------------------------------------------------------------------------

LoxVM *vm       @local;
int exitcode    @local;

//------------------------------------------------------------------------------

fn int main(String[] args)
{
    switch (args.len)
    {
        case 1:
            repl();

        case 2:
            run_script(args[1]);

        default:
            usage(true);
    }

    return exitcode;
}

//------------------------------------------------------------------------------

<*
    Initializes the global VM.
*>
fn void init_vm() @local
{
    LoxConfig config;
    lox::init_config(&config);

    vm = lox::new(&config);
}

<*
    Releases the memory held by the global VM.
*>
fn void free_vm() @local
{
    lox::free(vm);
}

<*
    Reads the contents of the file at [path] to a C string.

    @param path : "The path to the file to read."
*>
fn char *read_file(String path) @local
{
    char[]? result = file::load(mem, path);
    if (catch result)
    {
        io::eprintfn("Could not open file '%s'. Did you spell it right?", path);
        exitcode = 65;
        return null;
    }

    return &result[0];
}

<*
    Runs the Lox script found at [path] through the VM which compiles it and
    immediately interprets the resulting bytecode.

    @param path : "The path to the file to read."
*>
fn void run_script(String path) @local
{
    char *source = read_file(path);
    if (!source) return;
    defer free(source);

    init_vm();
    defer free_vm();

    if (catch e = lox::interpret(vm, source))
    {
        switch (e)
        {
            case lox::COMPILE_ERROR: exitcode = 65;
            case lox::RUNTIME_ERROR: exitcode = 70;
        }
    }
}

<*
    Runs the basic REPL for the Lox VM.
*>
fn void repl() @local
{
    init_vm();
    defer free_vm();

    for (;;)
    {
        io::print(">>> ");

        String? line = io::readline(mem);
        if (catch line)
        {
            io::printn();
            return;
        }

        @catch(lox::interpret(vm, line));
        line.free(mem);
    }
}

<*
    Prints the command-line usage information to the standard output.
*>
fn void usage(bool is_error = false) @local
{
    io::printn("Usage: lox [script]");
    if (is_error) exitcode = 64;
}
