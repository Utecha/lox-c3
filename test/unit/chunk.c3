import lox::chunk;
import lox::value;
import std::io @norecurse;


fn void! constant_long() @test
{
    Chunk chunk;
    chunk.init();
    defer chunk.free();

    /* Fix funky output */
    io::printn();

    for (int i = 0; i <= char.max; i++)
        { chunk.write_constant(number_val(69.0), 1); }

    for (int i = char.max; i < 288; i++)
        { chunk.write_constant(number_val(420.0), 2); }

    chunk.disassemble("Constant-Long Test");
}