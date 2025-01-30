module lox;

//------------------------------------------------------------------------------
// Lox
//------------------------------------------------------------------------------

fn int main(String[] args)
{
    int exit = 0;

    Vm vm;
    vm.init();
    defer vm.free();

    switch (args.len)
    {
        case 1: repl::repl(&vm);
        case 2: file::run(&vm, args[1]);
        default:
        {
            utils::logn(WARNING, "Usage: lox [script]");
            return 64;
        }
    }

    return 0;
}