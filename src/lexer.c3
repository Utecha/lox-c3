module lox::lexer;

enum TokenType : inline int
{
    // Delimiter
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    COMMA,
    DOT,
    SEMICOLON,

    // Arithmetic
    MINUS,
    PLUS,
    SLASH,
    STAR,

    // Assignment, Comparison and Equality
    EQUAL,
    EQEQ,
    NOT,
    NOTEQ,
    GT,
    GTEQ,
    LT,
    LTEQ,

    // Literals
    IDENTIFIER,
    NUMBER,
    STRING,

    // Keywords
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
    WHILE,

    // Special
    ERROR,
    EOF
}

struct Token
{
    TokenType type;
    String lexeme;
    int length;
    int line;
}

struct Lexer
{
    char *start;
    char *current;
    int line;
}

fn void Lexer.init(&self, char *source)
{
    self.start = source;
    self.current = source;
    self.line = 1;
}

fn char Lexer.advance(&self)
{
    return *self.current++;
}

fn char Lexer.peek(&self)
{
    return *self.current;
}

fn char Lexer.peek_next(&self)
{
    if (self.peek() == '\0') return '\0';
    return *(self.current + 1);
}

fn bool Lexer.match(&self, char c)
{
    if (self.peek() != c) return false;
    self.current++;
    return true;
}

fn Token Lexer.make_token(&self, TokenType type)
{
    return (Token) {
        .type = type,
        .lexeme = (String)self.start[:self.current - self.start],
        .length = (int)(self.current - self.start),
        .line = self.line
    };
}

fn Token Lexer.two_char_token(&self, char c, TokenType two, TokenType one)
{
    return self.make_token(self.match(c) ? two : one);
}

fn Token Lexer.error_token(&self, String message)
{
    return (Token) {
        .type = ERROR,
        .lexeme = message,
        .length = message.len,
        .line = self.line
    };
}

fn Token Lexer.identifier(&self)
{
    while (is_name(self.peek()) || is_digit(self.peek())) self.advance();

    switch (self.start[:self.current - self.start])
    {
        case "and":     return self.make_token(AND);
        case "class":   return self.make_token(CLASS);
        case "else":    return self.make_token(ELSE);
        case "false":   return self.make_token(FALSE);
        case "for":     return self.make_token(FOR);
        case "fun":     return self.make_token(FUN);
        case "if":      return self.make_token(IF);
        case "nil":     return self.make_token(NIL);
        case "or":      return self.make_token(OR);
        case "print":   return self.make_token(PRINT);
        case "return":  return self.make_token(RETURN);
        case "super":   return self.make_token(SUPER);
        case "this":    return self.make_token(THIS);
        case "true":    return self.make_token(TRUE);
        case "var":     return self.make_token(VAR);
        case "while":   return self.make_token(WHILE);
        default:        return self.make_token(IDENTIFIER);
    }
}

fn Token Lexer.number(&self)
{
    while (is_digit(self.peek())) self.advance();

    if (self.peek() == '.' && is_digit(self.peek_next()))
    {
        self.advance();
        while (is_digit(self.peek())) self.advance();
    }

    return self.make_token(NUMBER);
}

fn Token Lexer.string(&self)
{
    while (self.peek() != '"' && self.peek() != '\0')
    {
        if (self.peek() == '\n') self.line++;
        self.advance();
    }

    if (self.peek() == '\0') return self.error_token("Unterminated string");

    self.advance();
    return self.make_token(STRING);
}

fn void Lexer.skip_whitespace(&self)
{
    for (;;)
    {
        char c = self.peek();
        switch (c)
        {
            case ' ':
            case '\r':
            case '\t':
                self.advance();
            case '\n':
                self.line++;
                self.advance();
            case '/':
                if (self.peek_next() == '/')
                {
                    while (self.peek() != '\n' && self.peek() != '\0') self.advance();
                }
                else
                {
                    return;
                }
            default:
                return;
        }
    }
}

fn Token Lexer.next_token(&self)
{
    self.skip_whitespace();
    self.start = self.current;

    if (self.peek() == '\0') return self.make_token(EOF);

    char c = self.advance();
    if (is_name(c)) return self.identifier();
    if (is_digit(c)) return self.number();

    switch (c)
    {
        case '(':   return self.make_token(LPAREN);
        case ')':   return self.make_token(RPAREN);
        case '{':   return self.make_token(LBRACE);
        case '}':   return self.make_token(RBRACE);
        case ',':   return self.make_token(COMMA);
        case '.':   return self.make_token(DOT);
        case ';':   return self.make_token(SEMICOLON);
        case '-':   return self.make_token(MINUS);
        case '+':   return self.make_token(PLUS);
        case '/':   return self.make_token(SLASH);
        case '*':   return self.make_token(STAR);
        case '!':   return self.two_char_token('=', NOTEQ, NOT);
        case '=':   return self.two_char_token('=', EQEQ, EQUAL);
        case '>':   return self.two_char_token('=', GTEQ, GT);
        case '<':   return self.two_char_token('=', LTEQ, LT);
        case '"':   return self.string();
    }

    return self.error_token("Unexpected character");
}

fn bool is_name(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

fn bool is_digit(char c)
{
    return c >= '0' && c <= '9';
}
