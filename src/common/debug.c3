module lox::debug;

//------------------------------------------------------------------------------
// Lox | Debug
//------------------------------------------------------------------------------

const bool DUMP_CHUNK = false;
const bool DUMP_TOKENS = false;
const bool TRACE_EXEC = true;
const bool ENABLE_ALL = false;

//------------------------------------------------------------------------------
// Lox | Debug | Lexer
//------------------------------------------------------------------------------

module lox::debug::lexer @if($feature(DEBUG));
import lox::lexer, lox::token, lox::cli::utils;

fn void dump_tokens(String file, char *source)
{
    Lexer lexer;
    lexer.init(file, source);

    int line = -1;
    for (;;)
    {
        Token token = lexer.next_token();
        if (token.line != line)
        {
            utils::log(DEBUG, "%4d ", token.line);
            line = token.line;
        }
        else
        {
            utils::log(DEBUG, "   | ");
        }

        if (token.type == STRING)
            { utils::logn(NONE, "%-10s -- %s", token.type, token.lexeme); }
        else
            { utils::logn(NONE, "%-10s -- '%s'", token.type, token.lexeme); }

        if (token.type == TokenType.EOF) break;
    }
}

//------------------------------------------------------------------------------
// Lox | Debug | Chunk
//------------------------------------------------------------------------------
module lox::debug::chunk @if($feature(DEBUG));
import lox::cli::utils, lox::vm::chunk, lox::vm::opcodes, lox::vm::value;
import std::io @norecurse;

fn void print_opcodes()
{
    utils::logn(DEBUG, "=== Lox Opcodes ===");

    foreach (value : OpCode.values)
        { utils::logn(DEBUG, "%d: %s", value.ordinal, value); }

    io::eprintf("\n");
}

fn void Chunk.disassemble(&self, String name)
{
    utils::log(DEBUG, "=== %s ===", name);

    for (int offset = 0; offset < self.code.len();)
        { offset = self.disassemble_instruction(offset); }
}

fn int Chunk.disassemble_instruction(&self, int offset)
{
    utils::log(DEBUG, "%04d ", offset);

    int line = self.get_line(offset);
    if (offset > 0 && line == self.get_line(offset - 1))
        { utils::log(NONE, "   | "); }
    else
        { utils::log(NONE, "%4d ", line); }

    OpCode instruction = OpCode.from_ordinal(self.code[offset]);
    switch (instruction)
    {
        default:
            utils::log(NONE, "Unknown OpCode: %s", instruction);
            return offset + 1;

        /* Simple Instructions */
        case RETURN:
            return simple_instruction("RETURN", offset);
        case NIL:
            return simple_instruction("NIL", offset);
        case TRUE:
            return simple_instruction("TRUE", offset);
        case FALSE:
            return simple_instruction("FALSE", offset);
        case POP:
            return simple_instruction("POP", offset);
        case ADD:
            return simple_instruction("ADD", offset);
        case SUBTRACT:
            return simple_instruction("SUBTRACT", offset);
        case MULTIPLY:
            return simple_instruction("MULTIPLY", offset);
        case DIVIDE:
            return simple_instruction("DIVIDE", offset);
        case MODULO:
            return simple_instruction("MODULO", offset);
        case NEGATE:
            return simple_instruction("NEGATE", offset);
        case NOT:
            return simple_instruction("NOT", offset);
        case EQUAL:
            return simple_instruction("EQUAL", offset);
        case GREATER:
            return simple_instruction("GREATER", offset);
        case LESS:
            return simple_instruction("LESS", offset);
        case PRINT:
            return simple_instruction("PRINT", offset);

        /* Constant Instructions */
        case CONSTANT:
            return constant_instruction("CONSTANT", self, offset);
        case DEFINE_GLOBAL:
            return constant_instruction("DEFINE GLOBAL", self, offset);
        case GET_GLOBAL:
            return constant_instruction("GET GLOBAL", self, offset);
        case SET_GLOBAL:
            return constant_instruction("SET GLOBAL", self, offset);

        /* Byte Instructions */
        case GET_LOCAL:
            return byte_instruction("GET LOCAL", self, offset);
        case SET_LOCAL:
            return byte_instruction("SET LOCAL", self, offset);

        /* Jump Instructions */
        case JUMP:
            return jump_instruction("JUMP", 1, self, offset);
        case JUMP_IF_TRUE:
            return jump_instruction("JUMP IF TRUE", 1, self, offset);
        case JUMP_IF_FALSE:
            return jump_instruction("JUMP IF FALSE", 1, self, offset);
        case LOOP:
            return jump_instruction("LOOP", -1, self, offset);
    }
}

fn int byte_instruction(String name, Chunk *chunk, int offset) @local
{
    char slot = chunk.code[offset + 1];
    utils::logn(NONE, "%-14s %4d", name, slot);
    return offset + 2;
}

fn int jump_instruction(String name, int sign, Chunk *chunk, int offset) @local
{
    ushort jump = (ushort)(chunk.code[offset + 1] << 8);
    jump |= chunk.code[offset + 2];
    utils::logn(NONE, "%-14s %4d -> %d", name, offset, offset + 3 + sign * jump);
    return offset + 3;
}

fn int constantInstruction(String name, Chunk *chunk, int offset) @local
{
    int constant = chunk.code[offset + 1];
    utils::log(NONE, "%-14s %4d '", name, constant);
    value::print(chunk.constants[constant], io::stderr());
    utils::logn(NONE, "'");
    return offset + 2;
}

fn int simpleInstruction(String name, int offset) @local
{
    if (name == "RETURN")
        { utils::logn(NONE, "%s\n", name); }
    else
        { utils::logn(NONE, name); }

    return offset + 1;
}
