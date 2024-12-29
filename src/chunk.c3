module lox::chunk;
import lox::common;
import lox::mem;
import lox::value;

//------------------------------------------------------------------------------
// Lox \ Chunk
//------------------------------------------------------------------------------

enum OpCode : char
{
    /* Simple Instructions (1 byte) */
    RETURN,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NEGATE,

    /* Constant Instructions (2 bytes) */
    CONSTANT,
}

struct Chunk
{
    usz capacity;
    usz size;
    char *code;
    int *lines;
    ValueList constants;
}

fn void Chunk.init(&self)
{
    self.capacity = 0;
    self.size = 0;
    self.code = null;
    self.lines = null;
    self.constants.init();
}

fn void Chunk.free(&self)
{
    self.constants.free();
    mem::lfree(self.lines, self.capacity);
    mem::lfree(self.code, self.capacity);
    self.init();
}

fn void Chunk.write(&self, char byte, int line)
{
    if (self.capacity < self.size + 1)
    {
        usz old = self.capacity;
        self.capacity = nextPowOf2(old);
        self.code = mem::lrealloc(self.code, old, self.capacity);
        self.lines = mem::lrealloc(self.lines, old, self.capacity);
    }

    self.code[self.size] = byte;
    self.lines[self.size] = line;
    self.size++;
}

fn int Chunk.addConstant(&self, Value value)
{
    self.constants.append(value);
    return (int)self.constants.len() - 1;
}

fn char byte(int value) @builtin
{
    return (char)value;
}

//------------------------------------------------------------------------------
module lox::chunk @if($feature(DEBUG));
import lox::value;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ Chunk @if DEBUG
//------------------------------------------------------------------------------

fn void Chunk.disassemble(&self, String name)
{
    io::eprintfn("=== %s ===", name);

    for (int offset = 0; offset < self.size;)
    {
        offset = self.disassembleInstruction(offset);
    }
}

fn int Chunk.disassembleInstruction(&self, int offset)
{
    io::eprintf("%04d ", offset);

    int line = self.lines[offset];
    if (offset > 0 && line == self.lines[offset - 1])
    {
        io::eprintf("   | ");
    }
    else
    {
        io::eprintf("%4d ", line);
    }

    OpCode instruction = OpCode.from_ordinal(self.code[offset]);
    switch (instruction)
    {
        case RETURN:
            return simpleInstruction("RETURN", offset);
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
        case CONSTANT:
            return constantInstruction("CONSTANT", self, offset);
        default:
            io::eprintfn("Unknown OpCode: [ %s : %d ]", instruction, self.code[offset]);
            return offset + 1;
    }
}

fn int constantInstruction(String name, Chunk *chunk, int offset)
{
    char constant = chunk.code[offset + 1];
    io::eprintf("%-16s %4d '", name, constant);
    value::print(chunk.constants[constant], io::stderr());
    io::eprintf("'\n");
    return offset + 2;
}

fn int simpleInstruction(String name, int offset)
{
    io::eprintfn("%s", name);
    return offset + 1;
}
