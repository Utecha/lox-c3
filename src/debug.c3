module lox::vm::debug;

//------------------------------------------------------------------------------
// Lox \ Debug
//------------------------------------------------------------------------------

const bool DUMP_CHUNK = false;
const bool DUMP_TOKENS = false;
const bool TRACE_INSTRUCTIONS = false;
const bool ENABLE_ALL = true;

//------------------------------------------------------------------------------
// Lox \ Debug \ Chunk
//------------------------------------------------------------------------------
module lox::vm::debug::chunk @if($feature(DEBUG));
import lox::vm::chunk;
import lox::vm::opcodes;
import lox::vm::value;
import std::io @norecurse;

fn void printOpcodes()
{
    io::eprintfn("=== Lox Opcodes ===");

    foreach (value : OpCode.values)
        { io::eprintfn("%d: %s", value.ordinal, value); }

    io::eprintf("\n");
}

fn void Chunk.disassemble(&self, String name)
{
    io::eprintfn("=== %s ===", name);

    for (int offset = 0; offset < self.code.len();)
        { offset = self.disassembleInstruction(offset); }
}

fn int Chunk.disassembleInstruction(&self, int offset)
{
    io::eprintf("%04d ", offset);

    int line = self.getLine(offset);
    if (offset > 0 && line == self.getLine(offset - 1))
        { io::eprintf("   | "); }
    else
        { io::eprintf("%4d ", line); }

    OpCode instruction = OpCode.from_ordinal(self.code[offset]);
    switch (instruction)
    {
        default:
            io::eprintfn("Unknown OpCode: %s", instruction);
            return offset + 1;

        /* Simple Instructions */
        case RETURN:
            return simpleInstruction("RETURN", offset);
        case NIL:
            return simpleInstruction("NIL", offset);
        case TRUE:
            return simpleInstruction("TRUE", offset);
        case FALSE:
            return simpleInstruction("FALSE", offset);
        case POP:
            return simpleInstruction("POP", offset);
        case ADD:
            return simpleInstruction("ADD", offset);
        case SUBTRACT:
            return simpleInstruction("SUBTRACT", offset);
        case MULTIPLY:
            return simpleInstruction("MULTIPLY", offset);
        case DIVIDE:
            return simpleInstruction("DIVIDE", offset);
        case NEGATE:
            return simpleInstruction("NEGATE", offset);
        case NOT:
            return simpleInstruction("NOT", offset);
        case EQUAL:
            return simpleInstruction("EQUAL", offset);
        case GREATER:
            return simpleInstruction("GREATER", offset);
        case LESS:
            return simpleInstruction("LESS", offset);
        case PRINT:
            return simpleInstruction("PRINT", offset);

        /* Constant Instructions */
        case CONSTANT:
            return constantInstruction("CONSTANT", self, offset);
        case DEFINE_GLOBAL:
            return constantInstruction("DEFINE GLOBAL", self, offset);
        case GET_GLOBAL:
            return constantInstruction("GET GLOBAL", self, offset);
        case SET_GLOBAL:
            return constantInstruction("SET GLOBAL", self, offset);

        /* Byte Instructions */
        case GET_LOCAL:
            return byteInstruction("GET LOCAL", self, offset);
        case SET_LOCAL:
            return byteInstruction("SET LOCAL", self, offset);
    }
}

fn int byteInstruction(String name, Chunk *chunk, int offset)
{
    char slot = chunk.code[offset + 1];
    io::eprintfn("%-16s %4d", name, slot);
    return offset + 2;
}

fn int constantInstruction(String name, Chunk *chunk, int offset)
{
    int constant = chunk.code[offset + 1];
    io::eprintf("%-12s %4d '", name, constant);
    value::print(chunk.constants[constant], io::stderr());
    io::eprintfn("'");
    return offset + 2;
}

fn int simpleInstruction(String name, int offset)
{
    if (name == "RETURN")
        { io::eprintfn("%s\n", name); }
    else
        { io::eprintfn(name); }

    return offset + 1;
}
