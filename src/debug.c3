module lox::debug;
import lox::chunk;
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
        { offset = self.disassembleInstruction(offset); }
}

/*
 * Disassembles a single instruction at a given [offset] in a bytecode (Chunk).
*/
fn int Chunk.disassembleInstruction(&self, int offset)
{
    io::eprintf("%04d ", offset);

    int line = self.get_line(offset);
    if (offset > 0 && line == self.get_line(offset - 1))
        { io::eprintf("   | "); }
    else
        { io::eprintf("%4d ", line); }

    OpCode instruction = chunk::to_code(self.code[offset]);
    switch (instruction)
    {
        case CONSTANT_LONG:
            return constantLongInstruction(self, offset);
        case CONSTANT:
            return constantInstruction(self, offset);
        case NEGATE:
            return simpleInstruction("NEGATE", offset);
        case ADD:
            return simpleInstruction("ADD", offset);
        case SUBTRACT:
            return simpleInstruction("SUBTRACT", offset);
        case MULTIPLY:
            return simpleInstruction("MULTIPLY", offset);
        case DIVIDE:
            return simpleInstruction("DIVIDE", offset);
        case RETURN:
            return simpleInstruction("RETURN", offset);
    }
}

/*
 * Disassembles an (OpCode.CONSTANT_LONG) instruction.
*/
fn int constantLongInstruction(Chunk *chunk, int offset)
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
fn int constantInstruction(Chunk *chunk, int offset)
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
fn int simpleInstruction(String name, int offset)
{
    io::eprintfn(name);
    return offset + 1;
}