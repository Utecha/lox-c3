module lox::lexer @private;
import lox::cli::utils, lox::token;

//------------------------------------------------------------------------------
// Lox | Lexer @Helpers
//------------------------------------------------------------------------------

fn bool is_lower(char c)
{
    return (c >= 'a' && c <= 'z');
}

fn bool is_upper(char c)
{
    return (c >= 'A' && c <= 'Z');
}

fn bool is_alpha(char c)
{
    return is_lower(c) || is_upper(c);
}

fn bool is_digit(char c)
{
    return (c >= '0' && c <= '9');
}

fn bool is_alnum(char c)
{
    return is_alpha(c) || is_digit(c);
}

fn bool is_valid_identifier(char c)
{
    return is_alnum(c) || c == '_';
}

//------------------------------------------------------------------------------
// Lox | Lexer @public
//------------------------------------------------------------------------------

struct Lexer @public
{
    String file;
    char *start;
    char *current;
    int line;
}

fn void Lexer.init(&self, String file, char *source) @public
{
    self.file = file;
    self.start = source;
    self.current = source;
    self.line = 1;
}

fn Token Lexer.next_token(&self) @public
{
    if (catch error = self.skip_whitespace())
    {
        case LexError.NESTED_COMMENT:
            return self.error_token("Lox does not support nested block comments");
        case LexError.UNTERMINATED_COMMENT:
            return self.error_token("Unterminated comment block");
    }

    self.start = self.current;
    if (self.eof()) return self.make_token(EOF);

    char c = self.advance();
    if (is_alpha(c)) return self.identifier();
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
        case '%':   return self.make_token(MODULUS);
        case '!':   return self.make_token_duo('=', BANGEQ, BANG);
        case '=':   return self.make_token_duo('=', EQEQ, EQUAL);
        case '>':   return self.make_token_duo('=', GTEQ, GT);
        case '<':   return self.make_token_duo('=', LTEQ, LT);
        case '"':   return self.string();
        case '|':   if (self.match('|')) return self.make_token(OR);
        case '&':   if (self.match('&')) return self.make_token(AND);
    }

    return self.error_token("Unexpected character");
}

//------------------------------------------------------------------------------
// Lox | Lexer @private
//------------------------------------------------------------------------------

fault LexError
{
    NESTED_COMMENT,
    UNTERMINATED_COMMENT,
}

fn bool Lexer.eof(&self)
{
    return *self.current == '\0';
}

<*
    @require distance >= -2 && distance <= 2 "Cannot peek more than 2 character forward or backward"
*>
fn char Lexer.peek(&self, int distance = 0)
{
    return self.current[distance];
}

fn char Lexer.advance(&self)
{
    char c = self.peek();
    self.current++;
    return c;
}

fn bool Lexer.match(&self, char expected)
{
    if (self.peek() != expected) return false;
    self.current++;
    return true;
}

fn Token Lexer.make_token(&self, TokenType type)
{
    return Token {
        .type = type,
        .lexeme = (String)self.start[0 : self.current - self.start],
        .line = self.line
    };
}

fn Token Lexer.make_token_duo(&self, char c, TokenType two, TokenType one)
{
    return self.make_token(self.match(c) ? two : one);
}

fn Token Lexer.error_token(&self, String message)
{
    return Token {
        .type = ERROR,
        .lexeme = message,
        .line = self.line
    };
}

fn Token Lexer.identifier(&self)
{
    while (is_valid_identifier(self.peek())) self.advance();

    switch (self.start[0 : self.current - self.start])
    {
        case "and":     return self.make_token(AND);
        case "class":   return self.make_token(CLASS);
        case "else":    return self.make_token(ELSE);
        case "false":   return self.make_token(FALSE);
        case "for":     return self.make_token(FOR);
        case "fun":     return self.make_token(FUN);
        case "if":      return self.make_token(IF);
        case "nil":     return self.make_token(NIL);
        case "not":     return self.make_token(BANG);
        case "or":      return self.make_token(OR);
        case "print":   return self.make_token(PRINT);
        case "return":  return self.make_token(RETURN);
        case "super":   return self.make_token(SUPER);
        case "this":    return self.make_token(THIS);
        case "true":    return self.make_token(TRUE);
        case "var":     return self.make_token(VAR);
        case "while":   return self.make_token(WHILE);
        default:        break;
    }

    return self.make_token(IDENTIFIER);
}

fn Token Lexer.number(&self)
{
    while (is_digit(self.peek())) self.advance();

    if (self.peek() == '.' && is_digit(self.peek(1)))
    {
        self.advance();
        while (is_digit(self.peek())) self.advance();

        if (self.peek() == '.')
            { return self.error_token("Invalid floating point literal"); }
    }

    return self.make_token(NUMBER);
}

fn Token Lexer.string(&self)
{
    while (self.peek() != '"' && !self.eof())
    {
        if (self.peek() == '\n') self.line++;
        self.advance();
    }

    if (self.eof())
        { return self.error_token("Unterminated string"); }

    self.advance();
    return self.make_token(STRING);
}

fn void! Lexer.skip_block_comment(&self)
{
    while (true)
    {
        if (self.eof()) return LexError.UNTERMINATED_COMMENT?;
        self.advance();

        if (self.peek() == '/' && self.peek(1) == '*')
            { return LexError.NESTED_COMMENT?; }

        if (self.peek() == '*' && self.peek(1) == '/')
        {
            self.advance();
            self.advance();
            return;
        }
    }
}

fn void! Lexer.skip_whitespace(&self)
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
                if (self.peek(1) == '/')
                {
                    while (self.peek() != '\n' && !self.eof())
                        { self.advance(); }
                }
                else if (self.peek(1) == '*')
                {
                    self.skip_block_comment()!;
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