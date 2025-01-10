module lox::vm::opcodes;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ VM \ OpCodes
//------------------------------------------------------------------------------

/*
 * NOTE: The ordering of the elements of this enum are intentional and should not
 * be changed. This is to enforce a numerical representation hierarchy for safety
 * purposes during compilation and interpretation.
*/
enum OpCode : char
{
    /* Simple Instructions */
    RETURN,
    NIL,
    TRUE,
    FALSE,
    POP,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NEGATE,
    NOT,
    EQUAL,
    GREATER,
    LESS,
    PRINT,

    /* Constant Instructions */
    CONSTANT,
    DEFINE_GLOBAL,
    GET_GLOBAL,
    SET_GLOBAL,

    /* Byte Instructions */
    GET_LOCAL,
    SET_LOCAL,
}

fn char obyte(OpCode code) @builtin @inline => code.ordinal;
fn char ibyte(int constant) @builtin @inline => (char)constant;