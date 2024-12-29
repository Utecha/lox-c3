module lox::common;

//------------------------------------------------------------------------------
// Lox \ Chunk
//------------------------------------------------------------------------------

enum LoxResult : int
{
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
    SOURCE_ERROR,
    USAGE_ERROR,
}

/* Constants */
const uint DEFAULT_LIST_CAPACITY @builtin = 16U;

/* Debug Flags */
const bool DEBUG_DUMP_TOKENS    @builtin = true;
const bool DEBUG_PRINT_CODE     @builtin = false;
const bool DEBUG_TRACE_EXEC     @builtin = false;

/* Macros/Functions */
macro nextPowOf2(n) @builtin
{
    return n < 16U ? 16U : n * 2U;
}

fn bool isAlpha(char c) @builtin
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

fn bool isDigit(char c) @builtin
{
    return (c >= '0' && c <= '9');
}

fn bool isAlnum(char c) @builtin
{
    return isAlpha(c) || isDigit(c);
}
