module lox::opcode;

//--------------------------------------------------------------------------------------------------

<*
    The defined operation codes (instructions) for the Lox language.
*>
enum OpCode : char (String name, int stack_effect)
{
    // [1B] Instructions
    NIL             { "Nil", 1 },
    FALSE           { "False", 1 },
    TRUE            { "True", 1 },
    POP             { "Pop", -1 },
    NEGATE          { "Negate", 0 },
    NOT             { "Logical NOT", 1 },
    ADD             { "Add", -1 },
    SUB             { "Subtract", -1 },
    MUL             { "Multiply", -1 },
    DIV             { "Divide", -1 },
    MOD             { "Modulo", -1 },
    GREATER         { "Greater", -1 },
    LESS            { "Less", -1 },
    EQUAL           { "Equal", -1 },
    PRINT           { "Print", -1 },
    RETURN          { "Return", 0 },

    // [2B] Instructions
    GET_LOCAL       { "Get Local", 1 },
    SET_LOCAL       { "Set Local", 0 },

    // [3B] Instructions
    CONSTANT        { "Constant", 1 },
    DEFINE_GLOBAL   { "Define Global", -1 },
    GET_GLOBAL      { "Get Global", 1 },
    SET_GLOBAL      { "Set Global", 0 },
    JUMP            { "Jump", 0 },
    JUMP_IF         { "Jump If", -1 },
    LOOP            { "Loop", 0 },
    AND             { "Logical AND", -1 },
    OR              { "Logical OR", -1 },
}
