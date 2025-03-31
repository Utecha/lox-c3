module lox;
import std::io;

fn int main(String[] args)
{
    LoxVM vm;
    vm.init();
    defer vm.free();

    char[] text = "Hello, World!";
    Value string = value::newString(&vm, text);

    io::printfn("%s", asCString(string));
    return 0;
}
