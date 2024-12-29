module lox::lexer @private;
import lox::common;
import lox::token;

//------------------------------------------------------------------------------
// Lox \ Lexer
//------------------------------------------------------------------------------

struct Lexer @public
{
    char *start;
    char *current;
    int line;
}

fn void Lexer.init(&self, ZString source) @public
{
    self.start = source;
    self.current = source;
    self.line = 1;
}

fn Token Lexer.getNextToken(&self) @public
{
    self.skipWhitespace();
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
        case '!':   return self.makeTokenDuo(c, BANGEQ, BANG);
        case '=':   return self.makeTokenDuo(c, EQEQ, EQUAL);
        case '>':   return self.makeTokenDuo(c, GTEQ, GT);
        case '<':   return self.makeTokenDuo(c, LTEQ, LT);
        case '"':   return self.string();
    }

    return self.errorToken("Unexpected character");
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

fn Token Lexer.makeTokenDuo(&self, char c, TokenType one, TokenType two)
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
    while (isAlnum(self.peek())) self.advance();

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

fn void Lexer.skipWhitespace(&self)
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
                else
                {
                    return;
                }
            default:
                return;
        }
    }
}

//------------------------------------------------------------------------------
module lox::lexer @if($feature(DEBUG));
import lox::common;
import lox::token;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ Lexer @if DEBUG
//------------------------------------------------------------------------------

fn void dumpTokens(Lexer *lexer, ZString source) @if(DEBUG_DUMP_TOKENS)
{
    int line = -1;
    for (;;)
    {
        Token token = lexer.getNextToken();
        if (token.line != line)
        {
            io::printf("%4d ", token.line);
            line = token.line;
        }
        else
        {
            io::printf("   | ");
        }

        io::printfn("%-10s : '%s'", token.type, token.lexeme);
        if (token.type == TokenType.EOF) break;
    }
}
