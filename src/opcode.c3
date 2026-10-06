module lox::opcode;

//------------------------------------------------------------------------------

enum OpCode : char (String name)
{
    // [1B] Instructions
    NIL         { "Nil" },
    FALSE       { "False" },
    TRUE        { "True" },
    POP         { "Pop" },
    NEGATE      { "Negate" },
    NOT         { "Logical NOT" },
    ADD         { "Add" },
    SUB         { "Subtract" },
    MUL         { "Multiply" },
    DIV         { "Divide" },
    MOD         { "Modulo" },
    GREATER     { "Greater" },
    LESS        { "Less" },
    EQUAL       { "Equal" },
    RETURN      { "Return" },

    // [3B] Instructions
    CONSTANT   { "Constant" },
}
