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
    File? file = file::open(path, "rb");
    if (catch file)
    {
        io::eprintfn("Could not open file '%s'. Did you spell it right?", path);
        return null;
    }
    defer (void) file.close();

    sz? file_size = file.size();
    if (catch file_size)
    {
        io::eprintfn("Could not stat file '%s'.", path);
        return null;
    }

    char *buffer = (char *)malloc(file_size + 1);
    if (!buffer)
    {
        io::eprintfn("Not enough memory to read '%s'.", path);
        return null;
    }

    sz? bytes_read = file.read(buffer[:file_size]);
    if (catch bytes_read)
    {
        io::eprintfn("Could not read file '%s'.", path);
        return null;
    }

    buffer[bytes_read] = '\0';
    return buffer;
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
