module lox::chunk;
import lox::memory;
import lox::value;

//===----------------------------------------------------------------------===//
// Lox | Operation Codes
//===----------------------------------------------------------------------===//

enum OpCode : char
{
    /* Constant Long Instruction (four bytes) */
    CONSTANT_LONG,

    /* Constant Instructions (two bytes) */
    CONSTANT,

    /* Simple Instructions (one byte) */
    NEGATE,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    RETURN,
}

/*
 * Casts an 'OpCode' (or anything, really) to a 'char'.
 * This is mostly used to convert an 'OpCode' and 'int' index value of
 * a constant to a 'char' in order for it to fit into the bytecode array.
*/
macro char to_byte(code) => (char)code;

/*
 * Casts a [char] to an [OpCode]
 * This is mostly used by the VM itself and the disassembler.
*/
macro OpCode to_code(byte) => (OpCode)byte;

//===----------------------------------------------------------------------===//
// Lox | Bytecode 'Chunk'
//===----------------------------------------------------------------------===//

/*
 * A structure containing the line number and corresponding byte offset
 * for a given bytecode instruction.
 *
 * This is used to run-length encode the line information, lowering memory
 * usage. It has a downside of being much slower, however this is not a concern
 * as this is only ever comes into play when an error occurs.
*/
struct Line @private
{
    int number;
    int offset;
}

/*
 * A structure representing a literal 'chunk' of bytecode.
 *
 * This structure contains 3 separate dynamic arrays:
 *     1. code (char *) -- array of bytecode instructions
 *     2. lines (Line *) -- run-length encoded array of line numbers
 *     3. constants (ValueList) -- array of Lox (Value)s
*/
struct Chunk
{
    int capacity;
    int count;
    char *code;
    int line_capacity;
    int line_count;
    Line *lines;
    ValueList constants;
}

/* Zero-initializes a (Chunk) */
fn void Chunk.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.code = null;
    self.line_capacity = 0;
    self.line_count = 0;
    self.lines = null;
    self.constants.init();
}

/* Frees the memory contained within a (Chunk) and zero it out */
fn void Chunk.free(&self)
{
    self.constants.free();
    memory::free_array(int, self.lines, self.capacity);
    memory::free_array(char, self.code, self.capacity);
    self.init();
}

/*
 * Writes a byte and corresponding line number to a bytecode (Chunk).
 * Line numbers are run-length encoded, and are only ever written to conditionally.
*/
fn void Chunk.write(&self, char byte, int line) @private
{
    if (self.capacity < self.count + 1)
    {
        int old = self.capacity;
        self.capacity = memory::grow_capacity(old);
        self.code = memory::grow_array(char, self.code, old, self.capacity);
        if (!self.code) return;
    }

    if (self.count == 0 || self.lines[self.line_count - 1].number != line)
    {
        if (self.line_capacity < self.line_count + 1)
        {
            int line_old = self.line_capacity;
            self.line_capacity = memory::grow_capacity(line_old);
            self.lines = memory::grow_array(Line, self.lines, line_old, self.line_capacity);
            if (!self.lines) return;
        }

        self.lines[self.line_count] = { .number = line, .offset = self.count };
        self.line_count++;
    }

    self.code[self.count] = byte;
    self.count++;
}

/*
 * Appends a 'Value' to the constants array of a 'Chunk', returning the
 * index of that value.
*/
fn int Chunk.add_constant(&self, Value value)
{
    self.constants.append(value);
    return self.constants.count - 1;
}

/*
 * Write an OpCode (as a byte) to a bytecode 'Chunk'.
 *
 * This is the public API to the '.write()' method on a 'Chunk' for writing
 * an 'OpCode' to the bytecode array.
*/
fn void Chunk.write_opcode(&self, OpCode code, int line)
{
    self.write(to_byte(code), line);
}

/*
 * Write a possibly 'int' sized byte to a bytecode 'Chunk'.
 *
 * This is the public API to the '.write()' method on a 'Chunk' for writing
 * the index of a constant (provided by '.add_constant()') to the bytecode array.
*/
fn void Chunk.write_byte(&self, int byte, int line)
{
    self.write(to_byte(byte), line);
}

/*
 * Add's a constant [value] to the (Chunk)s constants pool, then writes
 * the appropriate instruction based on the index of that constant.
 *
 * If the index of [value] < 256, it writes an (OpCode.CONSTANT) instruction.
 * If the index of [value] > 256, it writes an (OpCode.CONSTANT_LONG) instruction.
 *
 * (OpCode.CONSTANT_LONG) has a 24-bit number as its operand, making the total size
 * 4 bytes long, compared to the 2 bytes of (OpCode.CONSANT).
*/
fn void Chunk.write_constant(&self, Value value, int line)
{
    int index = self.add_constant(value);

    if (index < 256)
    {
        self.write_opcode(CONSTANT, line);
        self.write_byte(index, line);
    }
    else
    {
        self.write_opcode(CONSTANT_LONG, line);
        self.write_byte((index >> 16) & 0xff, line);
        self.write_byte((index >> 8) & 0xff, line);
        self.write_byte(index & 0xff, line);
    }
}

/*
 * Returns the line number of an instruction at a given [offset].
 * In the event it cannot retrieve it, the method returns -1.
*/
fn int Chunk.get_line(&self, int offset)
{
    int start = 0;
    int end = self.line_count;

    while (start < end)
    {
        int mid = (start + end) / 2;
        Line *line = &self.lines[mid];

        if (offset < line.offset)
            { end = mid - 1; }
        else if (mid == self.line_count - 1 || offset < self.lines[mid + 1].offset)
            { return line.number; }
        else
            { start = mid + 1; }
    }

    return -1;
}