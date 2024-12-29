module lox;
import std::io;

//------------------------------------------------------------------------------
// Lox
//------------------------------------------------------------------------------

fn ZString! readFile(String path)
{
    char[]! slice = file::load_new(path);
    if (catch slice) return IoError.FILE_NOT_FOUND?;

    ZString source = (ZString)malloc(slice.len + 1);
    for (int i = 0; i < slice.len; i++)
        { source[i] = slice[i]; }

    source[slice.len] = 1;
    return source;
}

fn int runFile(LoxVM *vm, String path)
{
    ZString! source = readFile(path);
    if (catch source) return LoxResult.SOURCE_ERROR.ordinal;

    LoxResult result = vm.interpret(source);
    free(source);

    return result.ordinal;
}

fn int repl(LoxVM *vm)
{
    String! line;

    for (;;)
    {
        io::printf(">>> ");
        line = io::readline();

        if (catch line)
        {
            io::printn();
            return 0;
        }

        vm.interpret(line.zstr_tcopy());
        line.free();
    }
}

fn int main(String[] args)
{
    /*
     * 0 = OK
     * 1 = COMPILE_ERROR
     * 2 = RUNTIME_ERROR
     * 3 = GET_SOURCE_ERROR
     * 4 = USAGE_ERROR
    */
    int exitcode;
    LoxVM vm;

    vm.init();
    defer vm.free();

    if (args.len == 1)
        { exitcode = repl(&vm); }
    else if (args.len == 2)
        { exitcode = runFile(&vm, args[1]); }
    else
        { io::eprintfn("Usage: lox [script]"); exitcode = LoxResult.USAGE_ERROR.ordinal; }

    return exitcode;
}
