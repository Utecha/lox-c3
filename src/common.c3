module lox::common;
import lox::chunk;

//===----------------------------------------------------------------------===//
// Lox | Common
//===----------------------------------------------------------------------===//

/* Enable/disable VM stack tracing during disassembly */
const bool TRACE_INSTRUCTIONS   @builtin = true;

/*
 * Casts an (OpCode) (or anything, really) to a (char).
 * This is mostly used to convert an (OpCode) and (int) index value of
 * a constant to a (char) in order for it to fit into the bytecode array.
*/
macro char to_byte(code) @builtin
    => (char)code;

/*
 * Casts a (char) to an (OpCode).
 * This is mostly used by the VM itself and the disassembler.
*/
macro OpCode to_code(byte) @builtin
    => (OpCode)byte;

/* Faults defined specifically for Lox */
fault LoxError
{
    UNTERMINATED_COMMENT,
    USAGE
}