module lox::opcode;

//------------------------------------------------------------------------------

enum OpCode : char (String name, int stack_effect)
{
    // [1B] Instructions
    NIL         { "Nil", 1 },
    FALSE       { "False", 1 },
    TRUE        { "True", 1 },
    POP         { "Pop", -1 },
    NEGATE      { "Negate", 1 },
    NOT         { "Logical NOT", 1 },
    ADD         { "Add", 1 },
    SUB         { "Subtract", 1 },
    MUL         { "Multiply", 1 },
    DIV         { "Divide", 1 },
    MOD         { "Modulo", 1 },
    GREATER     { "Greater", 1 },
    LESS        { "Less", 1 },
    EQUAL       { "Equal", 1 },
    AND         { "Logical AND", -1 },
    OR          { "Logical OR", -1 },
    RETURN      { "Return", 0 },

    // [3B] Instructions
    CONSTANT   { "Constant", 1 },
}
