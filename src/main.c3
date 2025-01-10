module lox;
import std::io;

//------------------------------------------------------------------------------
// Lox
//------------------------------------------------------------------------------

macro elog(String fmt, args...) @builtin
{
    io::eprintf("Error: ");
    io::eprintfn(fmt, ...args);
}

fn int main(String[] args)
{
    int exit = 0;
    LoxVM vm;

    vm.init();
    defer vm.free();

    switch (args.len)
    {
        case 1:
            cli::repl(&vm);
        case 2:
            exit = cli::runFile(&vm, args[1]);
        default:
            elog("Usage: lox [script]");
            exit = 64;

    }

    return exit;
}
