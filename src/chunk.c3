module lox::chunk;
import lox::buffer, lox::value, lox::vm;

alias ByteBuffer = Buffer { char };
alias IntBuffer = Buffer { int };

enum OpCode : inline char (String name)
{
    // Simple Instructions (1 byte)
    FALSE           = "FALSE",
    NIL             = "NIL",
    TRUE            = "TRUE",
    NOT             = "NOT",
    NEGATE          = "NEGATE",
    ADD             = "ADD",
    SUBTRACT        = "SUBTRACT",
    MULTIPLY        = "MULTIPLY",
    DIVIDE          = "DIVIDE",
    EQUAL           = "EQUAL",
    GREATER         = "GREATER",
    LESS            = "LESS",
    POP             = "POP",
    CLOSE_UPVALUE   = "CLOSE UPVALUE",
    PRINT           = "PRINT",
    INHERIT         = "INHERIT",
    RETURN          = "RETURN",

    // Constant Instructions (2 bytes)
    CLASS           = "CLASS",
    CONSTANT        = "CONSTANT",
    METHOD          = "METHOD",
    DEFINE_GLOBAL   = "DEFINE GLOBAL",
    GET_GLOBAL      = "GET GLOBAL",
    SET_GLOBAL      = "SET GLOBAL",
    GET_PROPERTY    = "GET PROPERTY",
    SET_PROPERTY    = "SET PROPERTY",
    GET_SUPER       = "GET SUPER",

    // Byte Instructions (2 bytes)
    GET_LOCAL       = "GET LOCAL",
    SET_LOCAL       = "SET LOCAL",
    GET_UPVALUE     = "GET UPVALUE",
    SET_UPVALUE     = "SET UPVALUE",
    CALL            = "CALL",

    // Jump Instructions (3 bytes)
    JUMP            = "JUMP",
    JUMP_IF         = "JUMP IF",
    LOOP            = "LOOP",

    // Invoke Instruction (3 bytes)
    INVOKE          = "INVOKE",
    SUPER_INVOKE    = "SUPER INVOKE",

    // Closure Instruction (Variable bytes)
    CLOSURE         = "CLOSURE",
}

struct Chunk
{
    ByteBuffer code;
    IntBuffer lines;
    ValueBuffer constants;
}

// These have been left statically typed even though they are macros. I chose to
// make them macros over functions since the 'macro' keyword automatically
// inlines them.
macro char obyte(OpCode code)   @builtin => code.ordinal;
macro char ibyte(int byte)      @builtin => (char)byte;
macro OpCode opcode(int byte)   @builtin => OpCode.from_ordinal(byte);

fn void Chunk.init(&self)
{
    self.code.init();
    self.lines.init();
    self.constants.init();
}

fn void Chunk.free(&self, LoxVM *vm)
{
    self.constants.free(vm);
    self.lines.free(vm);
    self.code.free(vm);
    self.init();
}

fn void Chunk.write(&self, LoxVM *vm, char byte, int line)
{
    self.code.write(vm, byte);
    self.lines.write(vm, line);
}

fn int Chunk.add_constant(&self, LoxVM *vm, Value value)
{
    vm::@push(vm, value);
    self.constants.write(vm, value);
    vm::@pop(vm);
    return self.constants.len() - 1;
}

//------------------------------------------------------------------------------
module lox::chunk @if($feature(DEBUG));
import lox::value;
import std::io @norecurse;

fn void Chunk.disassemble(&self, String name)
{
    io::printfn("\n========= %s =========", name);

    for (int offset = 0; offset < self.code.len();)
    {
        offset = self.disassemble_instruction(offset);
    }
}

fn int Chunk.disassemble_instruction(&self, int offset)
{
    io::printf("%04d ", offset);

    int line = self.lines[offset];
    if (offset > 0 && line == self.lines[offset - 1])
    {
        io::print("   | ");
    }
    else
    {
        io::printf("%4d ", line);
    }

    OpCode instruction = opcode(self.code[offset]);
    switch (instruction)
    {
        case FALSE:
        case NIL:
        case TRUE:
        case NOT:
        case NEGATE:
        case ADD:
        case SUBTRACT:
        case MULTIPLY:
        case DIVIDE:
        case EQUAL:
        case GREATER:
        case LESS:
        case POP:
        case CLOSE_UPVALUE:
        case PRINT:
        case INHERIT:
        case RETURN:
            return simple_instruction(instruction.name, offset);
        case CLASS:
        case CONSTANT:
        case METHOD:
        case DEFINE_GLOBAL:
        case GET_GLOBAL:
        case SET_GLOBAL:
        case GET_PROPERTY:
        case SET_PROPERTY:
        case GET_SUPER:
            return constant_instruction(instruction.name, self, offset);
        case GET_LOCAL:
        case SET_LOCAL:
        case GET_UPVALUE:
        case SET_UPVALUE:
        case CALL:
            return byte_instruction(instruction.name, self, offset);
        case JUMP:
        case JUMP_IF:
            return jump_instruction(instruction.name, 1, self, offset);
        case LOOP:
            return jump_instruction(instruction.name, -1, self, offset);
        case INVOKE:
        case SUPER_INVOKE:
            return invoke_instruction(instruction.name, self, offset);
        case CLOSURE:
            offset++;
            char constant = self.code[offset++];
            io::printf("%-16s %4d ", instruction.name, constant);
            value::print(self.constants[constant]);
            io::printn();

            ObjFn *function = as_function(self.constants[constant]);
            for (int j = 0; j < function.upvalue_count; j++)
            {
                int is_local = self.code[offset++];
                int index = self.code[offset++];

                io::printfn(
                    "%04d      |                     %s %d",
                    offset - 2,
                    is_local ? "local" : "upvalue",
                    index
                );
            }

            return offset;
        default:
            io::printfn("Unknown OpCode: %s", instruction);
            return offset + 1;
    }
}

fn int byte_instruction(String name, Chunk *chunk, int offset)
{
    int slot = chunk.code[offset + 1];
    io::printfn("%-16s %4d", name, slot);
    return offset + 2;
}

fn int constant_instruction(String name, Chunk *chunk, int offset)
{
    int constant = chunk.code[offset + 1];
    io::printf("%-16s %4d '", name, constant);
    value::print(chunk.constants[constant]);
    io::printn("'");
    return offset + 2;
}

fn int invoke_instruction(String name, Chunk *chunk, int offset)
{
    char constant = chunk.code[offset + 1];
    char argc = chunk.code[offset + 2];
    io::printf("%-16s %4d '", name, constant);
    value::print(chunk.constants[constant]);
    io::printfn("' (%d args)", argc);
    return offset + 3;
}

fn int jump_instruction(String name, int sign, Chunk *chunk, int offset)
{
    ushort jump = (ushort)(chunk.code[offset + 1] << 8);
    jump |= chunk.code[offset + 2];
    io::printfn("%-16s %4d -> %d", name, offset, offset + 3 + sign * jump);
    return offset + 3;
}

fn int simple_instruction(String name, int offset)
{
    io::printn(name);
    return offset + 1;
}
