module lox::lexer;

//===----------------===//
//        Token
//===----------------===//

<*
    An enumerator of (Token) types.
*>
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
    COLON,
    QMARK,

    /* Logical (non-keyword) */
    NOT,

    /* Arithmetic - Factor */
    MODULUS,
    SLASH,
    STAR,

    /* Arithmetic - Term */
    MINUS,
    PLUS,

    /* Equality */
    ISEQ,
    NOTEQ,

    /* Comparison */
    GT,
    GTEQ,
    LT,
    LTEQ,

    /* Assignment */
    EQUAL,

    /* Literals */
    IDENTIFIER,
    NUMBER,
    STRING,

    /* Keywords */
    AND,        // also Logical
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,         // also Logical
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE
}

<*
    The structure representing a (Token) for Lox.

    There is a difference between this and the original struct in C. C3 has
    its own (String) type, that has a [len] field. For the purposes of lexing,
    I use a (char *), but it is converted into a (String) when the substring is
    made for the (Token) for convenience.
*>
struct Token
{
    TokenType type;
    String lexeme;
    int line;
}

//===----------------===//
//        Lexer
//===----------------===//

<*
    The structure representing the (Lexer) for Lox.
*>
struct Lexer
{
    char *start;
    char *current;
    int line;
}

/* Global (Lexer) object */
Lexer lexer @builtin;

<*
    Initializes the global [lexer] to the start of the source file.

    @param [in] source "The source code to be lexically analyzed"
*>
fn void init(char *source)
{
    lexer.start = source;
    lexer.current = source;
    lexer.line = 1;
}

<*
    Sets up the [lexer] and creates the next (Token). On the first pass, this is
    the first (Token) that can be made, starting from the beginning of the source code.

    @require lexer.start != null
    @require lexer.current != null
    @ensure lexer.start != null
    @ensure lexer.current != null
*>
fn Token get_next_token()
{
    skip_whitespace();
    lexer.start = lexer.current;

    if (at_end()) return make_token(TokenType.EOF);

    char c = advance();
    if (is_alpha(c)) return identifier();
    if (is_digit(c)) return number();

    switch (c)
    {
        case '(':   return make_token(TokenType.LPAREN);
        case ')':   return make_token(TokenType.RPAREN);
        case '{':   return make_token(TokenType.LBRACE);
        case '}':   return make_token(TokenType.RBRACE);
        case ',':   return make_token(TokenType.COMMA);
        case '.':   return make_token(TokenType.DOT);
        case ';':   return make_token(TokenType.SEMICOLON);
        case ':':   return make_token(TokenType.COLON);
        case '?':   return make_token(TokenType.QMARK);
        case '-':   return make_token(TokenType.MINUS);
        case '+':   return make_token(TokenType.PLUS);
        case '/':   return make_token(TokenType.SLASH);
        case '*':   return make_token(TokenType.STAR);
        case '!':   return make_token(match('=') ? TokenType.NOTEQ : TokenType.NOT);
        case '=':   return make_token(match('=') ? TokenType.ISEQ : TokenType.EQUAL);
        case '>':   return make_token(match('=') ? TokenType.GTEQ : TokenType.GT);
        case '<':   return make_token(match('=') ? TokenType.LTEQ : TokenType.LT);
        case '"':   return string();
    }

    return error_token("Unexpected character");
}

<*
    Creates an appropriate [token] based on the provided (TokenType), taking and converting
    the substring for the [lexeme] to a (String) and returning the [token].

    @param type "The TokenType tag for the Token"
*>
fn Token make_token(TokenType type) @private
{
    Token token;

    token.type = type;
    token.lexeme = (String)lexer.start[ : lexer.current - lexer.start];
    token.line = lexer.line;

    return token;
}

<*
    Creates an error [token], populating the tokens [lexeme] with an error message.
    This is used later in the parser to report the error.

    @param message "The error message for the error token"
*>
fn Token error_token(String message) @private
{
    Token token;

    token.type = TokenType.ERROR;
    token.lexeme = message;
    token.line = lexer.line;

    return token;
}

<*
    Returns 'true' if [c] is an alphabetic character, or if it is an underscore.
    Otherwise, it returns 'false'.

    @param c "The character to check"
*>
fn bool is_alpha(char c) @private
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

<*
    Returns 'true' if [c] is a numeric digit, otherwise it returns 'false'.

    @param c "The character to check"
*>
fn bool is_digit(char c) @private
{
    return c >= '0' && c <= '9';
}

<*
    Returns 'true' if [c] is an alpha-numeric character or an underscore.
    Otherwise, it returns 'false'.

    @param c "The character to check"
*>
fn bool is_alnum(char c) @private
{
    return is_alpha(c) || is_digit(c);
}

<*
    Returns 'true' if the [current] character the lexer is at is the null byte, otherwise
    it returns 'false'.

    @require lexer.current != null
*>
fn bool at_end() @private
{
    return *lexer.current == '\0';
}

<*
    Returns 'true' if the [current] character matches the [expected] one. If the expression is
    true, it also advances to the next character. Otherwise, it returns 'false'.

    @param expected "The character expected to be found next in the source code"
    @require lexer.current != null
*>
fn bool match(char expected) @private
{
    if (at_end()) return false;
    if (*lexer.current != expected) return false;

    lexer.current++;
    return true;
}

<*
    Advances [current] to the next character in the source code, returning the previous character.

    @require lexer.current != null
*>
fn char advance() @private
{
    lexer.current++;
    return *(lexer.current - 1);
}

<*
    Returns the [current] character being pointed to in the source code without advancing to the next.

    @require lexer.current != null
*>
fn char peek() @private
{
    return *lexer.current;
}

<*
    Returns the next character after the [current] character that is being pointed to in the source code,
    without advancing to the next. If the [lexer] is at the end of the source code, it returns the null byte.

    @require lexer.current != null
*>
fn char peek_next() @private
{
    if (at_end()) return '\0';
    return *(lexer.current + 1);
}

<*
    Run's on a loop to skip any and all whitespace. This also skips past any comments which are treated
    the same as whitespace.
*>
fn void skip_whitespace() @private
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
                    { while (peek() != '\n' && !at_end()) advance(); }
                else
                    { return; }
            default:
                return;
        }
    }
}

<*
    Lexes an identifier literal. If that identifier is equivalent to one of the built-in
    keywords, it returns a keyword-specific [token]. Otherwise, it returns a standard
    identifier [token].
*>
fn Token identifier() @private
{
    while (is_alnum(peek())) advance();

    String lexeme = (String)lexer.start[ : lexer.current - lexer.start];
    switch (lexeme)
    {
        case "and":     return make_token(TokenType.AND);
        case "class":   return make_token(TokenType.CLASS);
        case "else":    return make_token(TokenType.ELSE);
        case "false":   return make_token(TokenType.FALSE);
        case "for":     return make_token(TokenType.FOR);
        case "fun":     return make_token(TokenType.FUN);
        case "if":      return make_token(TokenType.IF);
        case "nil":     return make_token(TokenType.NIL);
        case "or":      return make_token(TokenType.OR);
        case "print":   return make_token(TokenType.PRINT);
        case "return":  return make_token(TokenType.RETURN);
        case "super":   return make_token(TokenType.SUPER);
        case "this":    return make_token(TokenType.THIS);
        case "true":    return make_token(TokenType.TRUE);
        case "var":     return make_token(TokenType.VAR);
        case "while":   return make_token(TokenType.WHILE);
        default:        return make_token(TokenType.IDENTIFIER);
    }
}

<*
    Lexes a number literal and returns a number [token].
*>
fn Token number() @private
{
    while (is_digit(peek())) advance();

    if (peek() == '.' && is_digit(peek_next()))
    {
        advance();

        while (is_digit(peek())) advance();
    }

    return make_token(TokenType.NUMBER);
}

<*
    Lexes a string literal and returns a string [token].
*>
fn Token string() @private
{
    while (peek() != '"' && !at_end())
    {
        if (peek() == '\n') lexer.line++;
        advance();
    }

    if (at_end()) return error_token("Unterminated string");

    advance();
    return make_token(TokenType.STRING);
}

//===----------------------------------------------------------------------===//
module lox::lexer @if($feature(DEBUG) &&& DUMP_TOKENS);
import lox::common;
import std::io @norecurse;

fn void dump_tokens(char *source)
{
    init(source);

    int line = -1;
    for (;;)
    {
        Token token = get_next_token();

        io::eprintfn("[ %s ]", token.type);

        if (token.type == TokenType.STRING)
            { io::eprintfn("--> Lexeme: %s", token.lexeme); }
        else if (token.type == TokenType.ERROR)
            { io::eprintfn("--> Message: \"%s\"", token.lexeme); }
        else
            { io::eprintfn("--> Lexeme: '%s'", token.lexeme); }

        io::eprintfn("--> Length: %d", token.lexeme.len);
        io::eprintfn("--> Line: %d\n", token.line);

        if (token.type == TokenType.EOF) break;
    }
}
