module lox;
import std::io;

int exitcode @local = 0;

fn char *read_file(String path) @local
{
    File? file = file::open(path, "rb");
    if (catch file)
    {
        io::eprintfn("Could not open file '%s'. Did you spell it right?", path);
        return null;
    }
    defer (void) file.close();

    usz file_size = file.seek(0, END)!!;
    file.seek(0, SET)!!;

    char *buffer = (char *)malloc(file_size + 1);
    if (!buffer)
    {
        io::eprintfn("Not enough memory to read '%s'", path);
        return null;
    }

    usz? bytes_read = file.read(buffer[:file_size]);
    if (catch bytes_read)
    {
        io::printfn("Could not read file '%s'", path);
        return null;
    }

    buffer[bytes_read] = '\0';
    return buffer;
}

fn void run_file(LoxVM *vm, String path) @local
{
    char *source = read_file(path);
    if (!source)
    {
        exitcode = 74;
        return;
    }
    defer free(source);

    if (catch excuse = vm.interpret(source))
    {
        switch (excuse)
        {
            case vm::COMPILE_ERROR:
                exitcode = 65;
            case vm::RUNTIME_ERROR:
                exitcode = 70;
        }
    }
}

fn void repl(LoxVM *vm)
{
    String? line;
    Allocator allocator = allocator::temp();

    @pool()
    {
        for (;;)
        {
            io::print(">>> ");

            line = io::readline(allocator);
            if (catch line)
            {
                io::printn();
                return;
            }

            if (line == "exit")
            {
                io::printn();
                return;
            }

            (void) vm.interpret(line);
        }
    };
}

fn int main(String[] args)
{
    LoxVM vm;
    vm.init();
    defer vm.free();

    switch (args.len)
    {
        case 1:
            repl(&vm);
        case 2:
            run_file(&vm, args[1]);
        default:
            io::eprintfn("Usage: lox [script]");
            exitcode = 64;;
    }

    return exitcode;
}
