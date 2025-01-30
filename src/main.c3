module lox;

//------------------------------------------------------------------------------
// Lox
//------------------------------------------------------------------------------

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
            utils::log(WARNING, "Usage: %slox%s [script]", utils::SYELLOW, utils::SRESET);
            exit = 64;
    }

    return exit;
}
