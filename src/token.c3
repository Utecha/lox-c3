module lox::token;
import std::io;

//------------------------------------------------------------------------------

enum TokenType : int (String name)
{
    // Operational Delimiters
    LPAREN      { "L Paren" },
    RPAREN      { "R Paren" },
    LBRACE      { "L Brace" },
    RBRACE      { "R Brace" },
    LBRACK      { "L Bracket" },
    RBRACK      { "R Bracket" },
    COMMA       { "Comma" },
    DOT         { "Dot" },
    COLON       { "Colon" },
    QUESTION    { "Question" },
    SEMICOLON   { "Semicolon" },

    // Assignment
    EQUAL       { "Equal" },

    // Equality
    ISEQ        { "Is Equal" },
    NOTEQ       { "Not Equal" },

    // Comparison
    GT          { "Greater" },
    GTEQ        { "Greater Equal" },
    LT          { "Less" },
    LTEQ        { "Less Equal" },

    // Arithmetic Term
    MINUS       { "Minus" },
    PLUS        { "Plus" },

    // Arithmetic Factor
    PERCENT     { "Percent" },
    SLASH       { "Slash" },
    STAR        { "Star" },

    // Literals
    IDENTIFIER  { "Identifier" },
    NUMBER      { "Number" },
    STRING      { "String" },

    // Keywords
    AND         { "[KW] Logical AND" },
    BREAK       { "[KW] Break" },
    CLASS       { "[KW] Class" },
    CONST       { "[KW] Const" },
    CONTINUE    { "[KW] Continue" },
    ELSE        { "[KW] Else" },
    FALSE       { "[KW] False" },
    FOR         { "[KW] For" },
    FUN         { "[KW] Fun" },
    IF          { "[KW] If" },
    NIL         { "[KW] Nil" },
    NOT         { "[KW] Logical NOT" },
    OR          { "[KW] Logical OR" },
    PRINT       { "[KW] Print" },
    RETURN      { "[KW] Return" },
    STATIC      { "[KW] Static" },
    SUPER       { "[KW] Super" },
    THIS        { "[KW] This" },
    TRUE        { "[KW] True" },
    VAR         { "[KW] VAR" },
    WHILE       { "[KW] While" },

    // Special
    ERROR       { "Error" },
    EOF         { "End of File" }
}

struct Token (Printable)
{
    TokenType type;
    String lexeme;
    sz length;
    int line;
}

//------------------------------------------------------------------------------

<*
    Converts the token [self] into a format string using the formatter [f].

    NOTE: This is not a method that is meant to be called directly. Similarly
    to operator overload methods, this method is called when passing the token
    to a print function (i.e. io::print(token)).

    @param [&inout] self : "A reference to the Token to format."
    @param [&inout] f : "The formatter to use."
*>
fn sz? Token.to_format(&self, Formatter *f) @dynamic
{
    sz length = f.printf("[ %s ]", self.type.name)!;

    if (self.type == EOF)
    {
        length += f.printf("\n")!;
        return length;
    }

    length += f.printf(
        " { '%s' :: len %d :: ln %d }\n",
        self.lexeme,
        self.length,
        self.line
    )!;

    return length;
}
