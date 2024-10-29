module lox::debug;
import lox::chunk;
import lox::common;
import lox::value;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Debug
//===----------------------------------------------------------------------===//

/*
 * In this version of Lox, this does not really do much more than disassemble
 * bytecode information. Version [0.2.0] will effectively "inline" all of this
 * into the same modules as the section of the project being debugged, making them
 * conditionally compiled.
*/

/*
 * Runs the .disassembleInstruction() method on a loop to completely disassemble a
 * bytecode (Chunk). Before doing so, it outputs a provided [name] for that chunk
 * in order to identify it.
*/
fn void Chunk.disassemble(&self, String name)
{
    io::eprintfn("=== %s ===", name);

    for (int offset = 0; offset < self.count;)
        { offset = self.disassemble_instruction(offset); }
}

/*
 * Disassembles a single instruction at a given [offset] in a bytecode (Chunk).
*/
fn int Chunk.disassemble_instruction(&self, int offset)
{
    io::eprintf("%04d ", offset);

    int line = self.get_line(offset);
    if (offset > 0 && line == self.get_line(offset - 1))
        { io::eprintf("   | "); }
    else
        { io::eprintf("%4d ", line); }

    OpCode instruction = to_code(self.code[offset]);
    switch (instruction)
    {
        case CONSTANT_LONG:
            return constant_long_instruction(self, offset);
        case CONSTANT:
            return constant_instruction(self, offset);
        case NEGATE:
            return simple_instruction("NEGATE", offset);
        case ADD:
            return simple_instruction("ADD", offset);
        case SUBTRACT:
            return simple_instruction("SUBTRACT", offset);
        case MULTIPLY:
            return simple_instruction("MULTIPLY", offset);
        case DIVIDE:
            return simple_instruction("DIVIDE", offset);
        case RETURN:
            return simple_instruction("RETURN", offset);
    }
}

/*
 * Disassembles an (OpCode.CONSTANT_LONG) instruction.
*/
fn int constant_long_instruction(Chunk *chunk, int offset)
{
    int index = (chunk.code[offset + 1] << 16) |
                (chunk.code[offset + 2] << 8) |
                (chunk.code[offset + 3]);
    io::eprintf("%-16s %4d '", "CONSTANT LONG", index);
    value::print(chunk.constants.values[index], io::stderr());
    io::eprintfn("'");
    return offset + 4;
}

/*
 * Disassembles an (OpCode.CONSTANT) instruction.
*/
fn int constant_instruction(Chunk *chunk, int offset)
{
    int index = chunk.code[offset + 1];
    io::eprintf("%-16s %4d '", "CONSTANT", index);
    value::print(chunk.constants.values[index], io::stderr());
    io::eprintfn("'");
    return offset + 2;
}

/*
 * Disassembles any simple (one byte) instruction.
*/
fn int simple_instruction(String name, int offset)
{
    io::eprintfn(name);
    return offset + 1;
}