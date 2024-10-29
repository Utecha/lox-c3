import lox::chunk;

fn void test_constant_long() @test
{
    Chunk chunk;
    chunk.init();
    defer chunk.free();

    for (int i = 0; i < 512; i++)
        { chunk.write_constant(69.0, 1); }

    chunk.disassemble("Constant-Long Test");
}