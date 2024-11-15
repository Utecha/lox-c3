module lox;

//===----------------===//
//     Entry Point
//===----------------===//

fn int main(String[] args)
{
    vm::init();
    defer vm::free();

    Chunk chunk;
    chunk.init();
    defer chunk.free();

    chunk.write_constant(12, 123);
    chunk.write_constant(5, 123);
    chunk.write_opcode(MODULUS, 123);
    chunk.write_constant(67, 123);
    chunk.write_opcode(ADD, 123);
    chunk.write_opcode(RETURN, 123);

    $if $feature(DEBUG) && DUMP_CHUNK:
        chunk.disassemble("Test Chunk");
    $else
        if (catch vm::interpret(&chunk)) return 70;
    $endif

    return 0;
}
