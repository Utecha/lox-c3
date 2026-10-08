module lox::lexer;
import lox::token;

//------------------------------------------------------------------------------

<*
    The lexical analyzer for the Lox language.
*>
struct LoxLexer
{
    char *source;
    char *start;
    char *current;
    int line;
}

//------------------------------------------------------------------------------

<*
    Initializes the given lexer with the given [source].

    @param [&inout] l : "A pointer to a LoxLexer."
    @param [&inout] source : "A pointer to the beginning of the source code."
*>
fn void init(LoxLexer *l, char *source)
{
    l.source = source;
    l.start = source;
    l.current = source;
    l.line = 1;
}

<*
    Reads through the source and returns the next token that was found.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
fn Token next(LoxLexer *l)
{
    skip_whitespace(l);
    setup_next_token(l);

    if (peek(l) == '\0') return make_token(l, EOF);

    char c = advance(l);
    if (is_ident_start(c)) return read_identifier(l);
    if (c.is_digit()) return read_number(l);
    if (c == '"') return read_string(l);

    switch (c)
    {
        case '(':   return make_token(l, LPAREN);
        case ')':   return make_token(l, RPAREN);
        case '{':   return make_token(l, LBRACE);
        case '}':   return make_token(l, RBRACE);
        case '[':   return make_token(l, LBRACK);
        case ']':   return make_token(l, RBRACK);
        case ',':   return make_token(l, COMMA);
        case '.':   return make_token(l, DOT);
        case ':':   return make_token(l, COLON);
        case '?':   return make_token(l, QUESTION);
        case ';':   return make_token(l, SEMICOLON);
        case '-':   return make_token(l, MINUS);
        case '+':   return make_token(l, PLUS);
        case '%':   return make_token(l, PERCENT);
        case '/':   return make_token(l, SLASH);
        case '*':   return make_token(l, STAR);
        case '!':   return two_char_token(l, '=', NOTEQ, NOT);
        case '=':   return two_char_token(l, '=', ISEQ, EQUAL);
        case '>':   return two_char_token(l, '=', GTEQ, GT);
        case '<':   return two_char_token(l, '=', LTEQ, LT);

        case '&':
            if (match(l, '&')) return make_token(l, AND);

        case '|':
            if (match(l, '|')) return make_token(l, OR);
    }

    return error_token(l, "Unexpected character");
}

//------------------------------------------------------------------------------

<*
    Sets the start of the next token to the current position in the source.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
macro void setup_next_token(LoxLexer *l) @local
{
    l.start = l.current;
}

<*
    Returns whether [c] is a valid starting character for an identifier.

    @param c : "The character to check."
*>
macro bool is_ident_start(char c) @local
{
    return c.is_alpha() || c == '_';
}

<*
    Returns whether [c] is a valid character for an identifier.

    @param c : "The character to check."
*>
macro bool is_ident_char(char c) @local
{
    return c.is_alnum() || c == '_';
}

<*
    Returns the current character being pointed to in the source without
    advancing to the next.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
macro char peek(LoxLexer *l) @local
{
    return *l.current;
}

<*
    Returns the next character being pointed to in the source without
    advancing to it.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
macro char peek_next(LoxLexer *l) @local
{
    if (peek(l) == '\0') return '\0';
    return *(l.current + 1);
}

<*
    Returns the current character being pointed to in the source and
    advances the pointer.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
macro char advance(LoxLexer *l) @local
{
    if (peek(l) == '\n') l.line++;
    return *l.current++;
}

<*
    Returns whether the current character being pointed to matches the
    [expected] one.

    @param [&inout] l : "A pointer to a LoxLexer."
    @param expected : "The expected character to match."
*>
fn bool match(LoxLexer *l, char expected) @local
{
    if (peek(l) != expected) return false;
    advance(l);
    return true;
}

<*
    Skips the current line in the source.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
fn void skip_line_comment(LoxLexer *l) @local
{
    while (peek(l) != '\n' && peek(l) != '\0') advance(l);
}

<*
    Skips past all whitespace found in the source up until the next
    valid character or until the end of the source.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
fn void skip_whitespace(LoxLexer *l) @local
{
    for (;;)
    {
        switch (peek(l))
        {
            case ' ':
            case '\r':
            case '\t':
            case '\n':
                advance(l);

            case '/':
                if (peek_next(l) == '/')
                {
                    skip_line_comment(l);
                    continue;
                }

                return;

            default:
                return;
        }
    }
}

<*
    Returns a new token based on the given [type].

    @param [&inout] l : "A pointer to a LoxLexer."
    @param type : "The type of the token to make."
*>
fn Token make_token(LoxLexer *l, TokenType type) @local
{
    return (Token) {
        .type = type,
        .lexeme = (String)l.start[:l.current - l.start],
        .length = l.current - l.start,
        .line = l.line
    };
}

<*
    Returns a new error token, initializing it with [message].

    @param [&inout] l : "A pointer to a LoxLexer."
    @param message : "The error message associated with the token."
*>
fn Token error_token(LoxLexer *l, String message) @local
{
    return (Token) {
        .type = ERROR,
        .lexeme = message,
        .length = message.len,
        .line = l.line
    };
}

<*
    Returns a new token based on whether the next character matches [c]. If it does,
    a token is made from type [two]. Otherwise, it is made from type [one].

    @param [&inout] l : "A pointer to a LoxLexer."
    @param c : "The character to match against."
    @param two : "The type used if the token is two characters long."
    @param one : "The type used if the token is one character long."
*>
fn Token two_char_token(LoxLexer *l, char c, TokenType two, TokenType one) @local
{
    return make_token(l, match(l, c) ? two : one);
}

<*
    Reads an identifier from the source and returns the corresponding token.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
fn Token read_identifier(LoxLexer *l) @local
{
    while (is_ident_char(peek(l))) advance(l);

    switch (l.start[:l.current - l.start])
    {
        case "and":         return make_token(l, AND);
        case "break":       return make_token(l, BREAK);
        case "class":       return make_token(l, CLASS);
        case "const":       return make_token(l, CONST);
        case "continue":    return make_token(l, CONTINUE);
        case "else":        return make_token(l, ELSE);
        case "false":       return make_token(l, FALSE);
        case "for":         return make_token(l, FOR);
        case "fun":         return make_token(l, FUN);
        case "if":          return make_token(l, IF);
        case "nil":         return make_token(l, NIL);
        case "not":         return make_token(l, NOT);
        case "or":          return make_token(l, OR);
        case "print":       return make_token(l, PRINT);
        case "return":      return make_token(l, RETURN);
        case "static":      return make_token(l, STATIC);
        case "super":       return make_token(l, SUPER);
        case "this":        return make_token(l, THIS);
        case "true":        return make_token(l, TRUE);
        case "var":         return make_token(l, VAR);
        case "while":       return make_token(l, WHILE);
        default:            return make_token(l, IDENTIFIER);
    }
}

<*
    Reads a number from the source. If successful, a number token is returned.
    Otherwise, an error token is returned.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
fn Token read_number(LoxLexer *l) @local
{
    while (peek(l).is_digit()) advance(l);

    if (peek(l) == '.' && peek_next(l).is_digit())
    {
        advance(l);
        while (peek(l).is_digit()) advance(l);
    }

    if (match(l, 'e') || match(l, 'E'))
    {
        if (!match(l, '+')) match(l, '-');

        if (!peek(l).is_digit())
        {
            return error_token(l, "Unterminated scientific notation.");
        }

        while (peek(l).is_digit()) advance(l);
    }

    return make_token(l, NUMBER);
}

<*
    Reads a string from the source. If successful, a string token is returned.
    Otherwise, an error token is returned.

    @param [&inout] l : "A pointer to a LoxLexer."
*>
fn Token read_string(LoxLexer *l) @local
{
    while (peek(l) != '"' && peek(l) != '\0') advance(l);

    if (peek(l) == '\0')
    {
        return error_token(l, "Unterminated string.");
    }

    advance(l); // Consume the closing quote.
    return make_token(l, STRING);
}
