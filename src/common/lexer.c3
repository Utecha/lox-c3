module lox::lexer @private;
import lox::token, lox::utils, lox::list;

//------------------------------------------------------------------------------
// Lox \ Lexer
//------------------------------------------------------------------------------

fault LexError
{
    NESTED_COMMENT,
    UNTERMINATED_COMMENT,
}

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

fn Token Lexer.getNextToken(&self) @public
{
    if (catch error = self.skipWhitespace())
    {
        case LexError.NESTED_COMMENT:
            return self.errorToken("Lox does not support nested block comments");
        case LexError.UNTERMINATED_COMMENT:
            return self.errorToken("Unterminated comment block");
    }

    self.start = self.current;
    if (self.eof()) return self.makeToken(EOF);

    char c = self.advance();
    if (isAlpha(c)) return self.identifier();
    if (isDigit(c)) return self.number();

    switch (c)
    {
        case '(':   return self.makeToken(LPAREN);
        case ')':   return self.makeToken(RPAREN);
        case '{':   return self.makeToken(LBRACE);
        case '}':   return self.makeToken(RBRACE);
        case ',':   return self.makeToken(COMMA);
        case '.':   return self.makeToken(DOT);
        case ';':   return self.makeToken(SEMICOLON);
        case '-':   return self.makeToken(MINUS);
        case '+':   return self.makeToken(PLUS);
        case '/':   return self.makeToken(SLASH);
        case '*':   return self.makeToken(STAR);
        case '!':   return self.makeTokenDuo('=', BANGEQ, BANG);
        case '=':   return self.makeTokenDuo('=', EQEQ, EQUAL);
        case '>':   return self.makeTokenDuo('=', GTEQ, GT);
        case '<':   return self.makeTokenDuo('=', LTEQ, LT);
        case '"':   return self.string();
        case '|':   if (self.match('|')) return self.makeToken(OR);
        case '&':   if (self.match('&')) return self.makeToken(AND);
    }

    return self.errorToken(string::format("Unexpected character: %c", c, allocator: allocator::heap()));
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

fn Token Lexer.makeToken(&self, TokenType type)
{
    return Token {
        .type = type,
        .lexeme = (String)self.start[0 : self.current - self.start],
        .line = self.line
    };
}

fn Token Lexer.makeTokenDuo(&self, char c, TokenType two, TokenType one)
{
    return self.makeToken(self.match(c) ? two : one);
}

fn Token Lexer.errorToken(&self, String message)
{
    return Token {
        .type = ERROR,
        .lexeme = message,
        .line = self.line
    };
}

fn Token Lexer.identifier(&self)
{
    while (isValidIdentifier(self.peek())) self.advance();

    switch (self.start[0 : self.current - self.start])
    {
        case "and":     return self.makeToken(AND);
        case "class":   return self.makeToken(CLASS);
        case "else":    return self.makeToken(ELSE);
        case "false":   return self.makeToken(FALSE);
        case "for":     return self.makeToken(FOR);
        case "fun":     return self.makeToken(FUN);
        case "if":      return self.makeToken(IF);
        case "nil":     return self.makeToken(NIL);
        case "not":     return self.makeToken(NOT);
        case "or":      return self.makeToken(OR);
        case "print":   return self.makeToken(PRINT);
        case "return":  return self.makeToken(RETURN);
        case "super":   return self.makeToken(SUPER);
        case "this":    return self.makeToken(THIS);
        case "true":    return self.makeToken(TRUE);
        case "var":     return self.makeToken(VAR);
        case "while":   return self.makeToken(WHILE);
        default:        break;
    }

    return self.makeToken(IDENTIFIER);
}

fn Token Lexer.number(&self)
{
    while (isDigit(self.peek())) self.advance();

    if (self.peek() == '.' && isDigit(self.peek(1)))
    {
        self.advance();
        while (isDigit(self.peek())) self.advance();
        
        if (self.peek() == '.')
            { return self.errorToken("Invalid floating point literal"); }
    }

    return self.makeToken(NUMBER);
}

fn Token Lexer.string(&self)
{
    while (self.peek() != '"' && !self.eof())
    {
        if (self.peek() == '\n') self.line++;
        self.advance();
    }

    if (self.eof())
        { return self.errorToken("Unterminated string"); }

    self.advance();
    return self.makeToken(STRING);
}

fn void! Lexer.skipBlockComment(&self)
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

fn void! Lexer.skipWhitespace(&self)
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
                    self.skipBlockComment()!;
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

fn bool isLower(char c)
{
    return (c >= 'a' && c <= 'z');
}

fn bool isUpper(char c)
{
    return (c >= 'A' && c <= 'Z');
}

fn bool isAlpha(char c)
{
    return isLower(c) || isUpper(c);
}

fn bool isDigit(char c)
{
    return (c >= '0' && c <= '9');
}

fn bool isAlnum(char c)
{
    return isAlpha(c) || isDigit(c);
}

fn bool isValidIdentifier(char c)
{
    return isAlnum(c) || c == '_';
}