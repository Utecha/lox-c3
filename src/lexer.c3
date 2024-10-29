module lox::lexer;
import lox::common;

//===----------------------------------------------------------------------===//
// Lox | Token Type
//===----------------------------------------------------------------------===//

enum TokenType : int
{
    /* Special */
    ERROR,
    EOF,

    /* Delimiter */
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    COMMA,
    DOT,
    SEMICOLON,

    /* Assignment */
    EQUAL,

    /* Equality */
    ISEQ,
    NOTEQ,

    /* Comparison */
    GT,
    GTEQ,
    LT,
    LTEQ,

    /* Arithmetic */
    MINUS,
    PLUS,
    SLASH,
    STAR,

    /* Logical (non-keyword) */
    NOT,

    /* Literal */
    IDENTIFIER,
    NUMBER,
    STRING,

    /* Keywords */
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

//===----------------------------------------------------------------------===//
// Lox | Token
//===----------------------------------------------------------------------===//

/* Data structure for a (Token) */
struct Token
{
    TokenType type;
    String lexeme;
    int line;
}

//===----------------------------------------------------------------------===//
// Lox | Lexer
//===----------------------------------------------------------------------===//

/* Returns true if [c] is in [a-zA-Z_] */
fn bool is_alpha(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

/* Returns true if [c] is in [0-9] */
fn bool is_digit(char c)
{
    return c >= '0' && c <= '9';
}

/* Returns true if [c] is in [a-zA-Z0-9_] */
fn bool is_alnum(char c)
{
    return is_alpha(c) || is_digit(c);
}

/* Data structure for a (Lexer) */
struct Lexer
{
    char *start;
    char *current;
    int line;
}

Lexer lexer @builtin;

/* Initialize a new Lexer */
fn void init(char *source)
{
    lexer.start = source;
    lexer.current = source;
    lexer.line = 1;
}

fn bool eof() @private
{
    return *lexer.current == '\0';
}

fn bool match(char expected) @private
{
    if (eof()) return false;
    if (*lexer.current != expected) return false;

    lexer.current++;
    return true;
}

fn char advance() @private
{
    lexer.current++;
    return lexer.current[-1];
}

fn char peek() @private
{
    return *lexer.current;
}

fn char peek_next() @private
{
    if (eof()) return '\0';
    return lexer.current[1];
}

fn void skip_ln_comment() @private
{
    while (peek() != '\n' && !eof()) advance();
}

fn void! skip_block_comment() @private
{
    for (;;)
    {
        if (eof()) return LoxError.UNTERMINATED_COMMENT?;

        if (peek() == '\n') lexer.line++;

        if (peek() == '*' && peek_next() == '/')
        {
            advance();
            advance();
            break;
        }

        advance();
    }
}

fn void! skip_whitespace() @private
{
    for (;;)
    {
        char c = peek();
        switch (c)
        {
            case ' ':
            case '\r':
            case '\t':
                advance();
            case '\n':
                lexer.line++;
                advance();
            case '/':
                if (peek_next() == '/')
                    { skip_ln_comment(); }
                else if (peek_next() == '*')
                    { skip_block_comment()!; }
                else
                    { return; }
            default:
                return;
        }
    }
}

fn Token make_token(TokenType type) @private
{
    Token token;
    token.type = type;
    token.lexeme = (String)lexer.start[0 : lexer.current - lexer.start];
    token.line = lexer.line;
    return token;
}

fn Token error_token(String message) @private
{
    Token token;
    token.type = TokenType.ERROR;
    token.lexeme = message;
    token.line = lexer.line;
    return token;
}

fn Token identifier() @private
{
    while (is_alnum(peek())) advance();

    String lexeme = (String)lexer.start[0 : lexer.current - lexer.start];
    switch (lexeme)
    {
        case "and":     return make_token(AND);
        case "class":   return make_token(CLASS);
        case "else":    return make_token(ELSE);
        case "false":   return make_token(FALSE);
        case "for":     return make_token(FOR);
        case "fun":     return make_token(FUN);
        case "if":      return make_token(IF);
        case "nil":     return make_token(NIL);
        case "or":      return make_token(OR);
        case "print":   return make_token(PRINT);
        case "return":  return make_token(RETURN);
        case "super":   return make_token(SUPER);
        case "this":    return make_token(THIS);
        case "true":    return make_token(TRUE);
        case "var":     return make_token(VAR);
        case "while":   return make_token(WHILE);
        default:        return make_token(IDENTIFIER);
    }
}

fn Token number() @private
{
    while (is_digit(peek())) advance();

    if (peek() == '.' && is_digit(peek_next()))
    {
        advance();
        while (is_digit(peek())) advance();
    }

    return make_token(NUMBER);
}

fn Token string() @private
{
    while (peek() != '"' && !eof())
    {
        if (peek() == '\n') lexer.line++;
        advance();
    }

    if (eof())
        { return error_token("Unterminated string"); }

    advance();
    return make_token(STRING);
}

fn Token get_token()
{
    if (catch skip_whitespace())
        { return error_token("Unterminated comment block."); }

    lexer.start = lexer.current;
    if (eof()) return make_token(EOF);

    char c = advance();
    if (is_alpha(c)) return identifier();
    if (is_digit(c)) return number();

    switch (c)
    {
        case '(':   return make_token(LPAREN);
        case ')':   return make_token(RPAREN);
        case '{':   return make_token(LBRACE);
        case '}':   return make_token(RBRACE);
        case ',':   return make_token(COMMA);
        case '.':   return make_token(DOT);
        case ';':   return make_token(SEMICOLON);
        case '-':   return make_token(MINUS);
        case '+':   return make_token(PLUS);
        case '/':   return make_token(SLASH);
        case '*':   return make_token(STAR);
        case '"':   return string();

        case '!':
            return make_token(match('=') ? TokenType.NOTEQ : TokenType.NOT);
        case '=':
            return make_token(match('=') ? TokenType.ISEQ : TokenType.EQUAL);
        case '>':
            return make_token(match('=') ? TokenType.GTEQ : TokenType.GT);
        case '<':
            return make_token(match('=') ? TokenType.LTEQ : TokenType.LT);
    }

    return error_token("Unexpected character");
}