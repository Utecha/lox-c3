import lox::chunk;


fn void! test_constant_long() @test
{
    Chunk chunk;
    chunk.init();
    defer chunk.free();

    for (int i = 0; i <= char.max; i++)
        { chunk.write_constant(69.0, 1); }

    for (int i = char.max; i < 384; i++)
        { chunk.write_constant(420.0, 2); }

    chunk.disassemble("Constant-Long Test");
}