module lox::token;

//------------------------------------------------------------------------------
// Lox \ Token
//------------------------------------------------------------------------------

enum TokenType : int
{
    ERROR,
    EOF,

    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    COMMA,
    DOT,
    SEMICOLON,

    MINUS,
    PLUS,
    SLASH,
    STAR,

    BANG,
    BANGEQ,
    EQUAL,
    EQEQ,
    GT,
    GTEQ,
    LT,
    LTEQ,

    IDENTIFIER,
    NUMBER,
    STRING,

    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE
}

struct Token
{
    TokenType type;
    String lexeme;
    int line;
}
