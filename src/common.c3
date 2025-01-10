module lox::common;

//------------------------------------------------------------------------------
// Lox \ Common
//------------------------------------------------------------------------------

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
