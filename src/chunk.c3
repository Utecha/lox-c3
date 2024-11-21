module lox::chunk;
import lox::memory;
import lox::object;
import lox::value;
import lox::vm;

//===----------------===//
//   Operation Codes
//===----------------===//

/*
 * Enumerator of Operation Codes defined for the Lox VM.
 *
 * NOTE: Different instructions load different numbers of bytes.
 * Comments within the enum will denote the instruction type as well
 * as the number of bytes associated with each instruction.
*/
enum OpCode : char
{
    /* Jump Instructions (3 bytes) */
    JUMP,           // Unconditional jump
    JUMP_IF_FALSE,  // Conditional jump
    LOOP,           // Multi-conditional reverse jump

    /* Constant Instructions (2 bytes) */
    CLOSURE,
    CONSTANT,
    DEFINE_GLOBAL,
    GET_GLOBAL,
    SET_GLOBAL,
    GET_UPVALUE,
    SET_UPVALUE,

    /* Byte Instructions (2 bytes) */
    CALL,
    GET_LOCAL,
    SET_LOCAL,

    /* Simple Instructions (1 byte) */
    CLOSE_UPVALUE,
    NOT,
    NIL,
    TRUE,
    FALSE,
    EQUAL,
    GREATER,
    LESS,
    TERNARY,
    NEGATE,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    MODULUS,
    POP,
    PRINT,
    RETURN,
}

//===----------------===//
//        Chunk
//===----------------===//

<*
    The structure representing compressed line information.
*>
struct Line
{
    int number;
    int offset;
}

<*
    The structure representing a 'chunk' of Lox bytecode.
*>
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

<*
    Initializes a new (Chunk).

    @param [&inout] self "A reference to the chunk the method is called on"
*>
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

<*
    Free the memory of an exisiting (Chunk).

    @param [&inout] self "A reference to the chunk the method is called on"
*>
fn void Chunk.free(&self)
{
    memory::free_array(Line, self.lines, self.line_capacity);
    memory::free_array(char, self.code, self.capacity);
    self.init();
}

<*
    Write a byte instruction to the bytecode array of a 'Chunk'.

    @param [&inout] self "A reference to the chunk the method is called on"
    @param byte "The byte to write to the chunks bytecode array"
    @param line "The corresponding line number the instruction appears on"
*>
fn void Chunk.write(&self, char byte, int line)
{
    if (self.capacity < self.count + 1)
    {
        int old_cap = self.capacity;
        self.capacity = memory::grow_capacity(old_cap);
        self.code = memory::grow_array(char, self.code, old_cap, self.capacity);
    }

    if (self.count == 0 || self.lines[self.line_count - 1].number != line)
    {
        if (self.line_capacity < self.line_count + 1)
        {
            int old_line_cap = self.line_capacity;
            self.line_capacity = memory::grow_capacity(old_line_cap);
            self.lines = memory::grow_array(Line, self.lines, old_line_cap, self.line_capacity);
        }

        self.lines[self.line_count] = { .number = line, .offset = self.count };
        self.line_count++;
    }

    self.code[self.count] = byte;
    self.count++;
}

<*
    Typecasts a value to (char).

    NOTE: This is not to be confused with the 'Value' from Lox.
    This refers to a literal C3 value.

    @param value "The value to typecast to char"
*>
macro to_byte(value) @builtin => (char)value;

<*
    Typecasts a (char) to an (OpCode).

    @param byte "The byte to typecast to an OpCode"
*>
macro to_opcode(byte) @builtin => (OpCode)byte;

<*
    Add's a 'Value' to a chunks constants pool and returns the index.

    @param [&inout] self "A reference to the chunk the method is called on"
    @param value "The value to write to the constants pool"
*>
fn int Chunk.add_constant(&self, Value value)
{
    vm::push(value);
    self.constants.append(value);
    vm::pop();
    return self.constants.count - 1;
}

<*
    Binary-search algorithm for obtaining the a chunks line information.

    @param [&inout] self "A reference to the chunk the method is called on"
    @param offset "The index within the bytecode array corresponding to a line number"
*>
fn int Chunk.get_line(&self, int offset)
{
    int start = 0;
    int end = self.line_count;

    while (start < end)
    {
        int mid = (start + end) / 2;
        Line *line = &self.lines[mid];

        if (offset < line.offset)
            { end = mid; }
        else if (mid == self.line_count - 1 || offset < self.lines[mid + 1].offset)
            { return line.number; }
        else
            { start = mid + 1; }
    }

    return -1;
}

//===----------------------------------------------------------------------===//
module lox::chunk @if($feature(DEBUG) &&& (DUMP_CHUNK ||| TRACE_INSTRUCTIONS));
import lox::common;
import lox::object;
import lox::value;
import std::io @norecurse;

//===----------------===//
//     Disassembler
//===----------------===//

<*
    Disassembles an entire bytecode 'Chunk'.

    @param [&inout] self "A reference to the chunk the method is called on"
    @param name "A name for the chunk being disassembled"
*>
fn void Chunk.disassemble(&self, String name)
{
    io::eprintfn("=== %s ===", name);

    for (int offset = 0; offset < self.count;)
        { offset = self.disassemble_instruction(offset); }
}

<*
    Disassembles an individual instruction within a bytecode 'Chunk'.

    @param [&inout] self "A reference to the chunk the method is called on"
    @param offset "The index of the instruction to disassemble"
*>
fn int Chunk.disassemble_instruction(&self, int offset)
{
    io::eprintf("%04d ", offset);

    int line = self.get_line(offset);
    if (offset > 0 && line == self.get_line(offset - 1))
        { io::eprintf("   | "); }
    else
        { io::eprintf("%4d ", line); }

    OpCode instruction = (OpCode)self.code[offset];
    switch (instruction)
    {
        case JUMP:
            return jump_instruction("JUMP", 1, self, offset);
        case JUMP_IF_FALSE:
            return jump_instruction("JUMP IF FALSE", 1, self, offset);
        case LOOP:
            return jump_instruction("LOOP", -1, self, offset);
        case CLOSURE:
            return closure_instruction(self, offset);
        case CONSTANT:
            return constant_instruction("CONSTANT", self, offset);
        case DEFINE_GLOBAL:
            return constant_instruction("DEFINE GLOBAL", self, offset);
        case GET_GLOBAL:
            return constant_instruction("GET GLOBAL", self, offset);
        case SET_GLOBAL:
            return constant_instruction("SET GLOBAL", self, offset);
        case GET_UPVALUE:
            return byte_instruction("GET UPVALUE", self, offset);
        case SET_UPVALUE:
            return byte_instruction("SET UPVALUE", self, offset);
        case CALL:
            return byte_instruction("CALL", self, offset);
        case GET_LOCAL:
            return byte_instruction("GET LOCAL", self, offset);
        case SET_LOCAL:
            return byte_instruction("SET LOCAL", self, offset);
        case CLOSE_UPVALUE:
            return simple_instruction("CLOSE_UPVALUE", offset);
        case NOT:
            return simple_instruction("NOT", offset);
        case NIL:
            return simple_instruction("NIL", offset);
        case TRUE:
            return simple_instruction("TRUE", offset);
        case FALSE:
            return simple_instruction("FALSE", offset);
        case EQUAL:
            return simple_instruction("EQUAL", offset);
        case GREATER:
            return simple_instruction("GREATER", offset);
        case LESS:
            return simple_instruction("LESS", offset);
        case TERNARY:
            return simple_instruction("TERNARY", offset);
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
        case MODULUS:
            return simple_instruction("MODULUS", offset);
        case POP:
            return simple_instruction("POP", offset);
        case PRINT:
            return simple_instruction("PRINT", offset);
        case RETURN:
            return simple_instruction("RETURN", offset);
    }
}

<*
    Disassembles a byte (simple 2 byte) instruction.

    @param name "The name of the instruction"
    @param [&in] chunk "A reference to the chunk to disassemble"
    @param offset "The index of the instruction in the bytecode array"
*>
fn int byte_instruction(String name, Chunk *chunk, int offset) @private
{
    char slot = chunk.code[offset + 1];
    io::eprintfn("%-16s %4d", name, slot);
    return offset + 2;
}

<*
    Disassembles a closure (2 byte) instruction.

    @param [&in] chunk "A reference to the chunk to disassemble"
    @param offset "The index of the instruction in the bytecode array"
*>
fn int closure_instruction(Chunk *chunk, int offset) @private
{
    offset++;
    char constant = chunk.code[offset++];

    io::eprintf("%-16s %4d ", "CLOSURE", constant);
    value::print(chunk.constants.values[constant], io::stderr());
    io::eprintf("\n");

    ObjFunction *function = as_function(chunk.constants.values[constant]);
    for (int j = 0; j < function.upvalue_count; j++)
    {
        int is_local = chunk.code[offset++];
        int index = chunk.code[offset++];

        io::eprintfn(
            "%04d    |                     %s %d",
            offset - 2,
            is_local ? "local" : "upvalue",
            index
        );
    }

    return offset;
}

<*
    Disassembles a constant (2 byte) instruction.

    @param name "The name of the instruction"
    @param [&in] chunk "A reference to the chunk to disassemble"
    @param offset "The index of the instruction in the bytecode array"
*>
fn int constant_instruction(String name, Chunk *chunk, int offset) @private
{
    int index = chunk.code[offset + 1];

    io::eprintf("%-16s %4d '", name, index);
    value::print(chunk.constants.values[index], io::stderr());
    io::eprintfn("'");

    return offset + 2;
}

<*
    Disassembles a jump (3 byte) instruction.

    NOTE: The 'sign' in this instance is used to denote in which direction to jump in the code.
    Jump instructions used in something like an 'if' statement jump forward, so they have a
    positive (+1) signedness. Jump instructions such as a the 'LOOP' instruction jump backwards,
    therefore they have a negative (-1) signedness.

    @param name "The name of the instruction"
    @param sign "A directional (negative or positive) offset denoting the direction the code jumps"
    @param [&in] chunk "A reference to the chunk to disassemble"
    @param offset "The index of the instruction in the bytecode array"
*>
fn int jump_instruction(String name, int sign, Chunk *chunk, int offset) @private
{
    ushort jump = (ushort)(chunk.code[offset + 1] << 8);
    jump |= chunk.code[offset + 2];

    io::eprintfn("%-16s %4d -> %d", name, offset, offset + 3 + sign * jump);
    return offset + 3;
}

<*
    Disassembles a simple (1 byte) instruction.

    @param name "The name of the instruction"
    @param offset "The index of the instruction in the bytecode array"
*>
fn int simple_instruction(String name, int offset) @private
{
    if (name == "RETURN")
        { io::eprintfn("%s\n", name); }
    else
        { io::eprintfn("%s", name); }

    return offset + 1;
}
