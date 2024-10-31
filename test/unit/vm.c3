import lox::chunk;
import lox::compiler;
import lox::vm @public;
import std::io @norecurse;



fn void constant_long_vm() @test
{
    vm::init();
    defer vm::free();

    Chunk chunk;
    chunk.init();
    defer chunk.free();

    char *source = lox::read_file("test/compiler/constant_long.lox")!;
    defer mem::free(source);

    /* Fix funky output */
    io::printn();

    if (!compiler::compile(source, &chunk))
        { return VmResult.COMPILE_ERROR?; }

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code;
    return vm::run_interpreter()!;
}

fn void string_operations() @test
{
    vm::init();
    defer vm::free();

    Chunk chunk;
    chunk.init();
    defer chunk.free();

    char *source = lox::read_file("test/compiler/strings.lox")!;
    defer mem::free(source);
    io::printn();

    if (!compiler::compile(source, &chunk))
        { return VmResult.COMPILE_ERROR?; }

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code;
    return vm::run_interpreter()!;
}