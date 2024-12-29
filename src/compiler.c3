module lox::compiler @private;
import lox::chunk;
import lox::common;
import lox::lexer;
import lox::token;
import lox::value;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ Parser
//------------------------------------------------------------------------------

struct Parser
{
    Lexer lexer;
    Token current;
    Token previous;
    bool hadError;
    bool panicMode;
}

enum Precedence : int
{
    NONE,
    ASSIGNMENT,
    OR,
    AND,
    EQUALITY,
    COMPARISON,
    TERM,
    FACTOR,
    UNARY,
    CALL,
    PRIMARY
}

def ParseFn = fn void (Compiler *compiler);

struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

ParseRule[] rules = {
    [TokenType.ERROR.ordinal]      = { null,               null,                   NONE },
    [TokenType.EOF.ordinal]        = { null,               null,                   NONE },
    [TokenType.LPAREN.ordinal]     = { &Compiler.grouping, null,                   NONE },
    [TokenType.RPAREN.ordinal]     = { null,               null,                   NONE },
    [TokenType.LBRACE.ordinal]     = { null,               null,                   NONE }, 
    [TokenType.RBRACE.ordinal]     = { null,               null,                   NONE },
    [TokenType.COMMA.ordinal]      = { null,               null,                   NONE },
    [TokenType.DOT.ordinal]        = { null,               null,                   NONE },
    [TokenType.SEMICOLON.ordinal]  = { null,               null,                   NONE },
    [TokenType.MINUS.ordinal]      = { &Compiler.unary,    &Compiler.binary,       TERM },
    [TokenType.PLUS.ordinal]       = { null,               &Compiler.binary,       TERM },
    [TokenType.SLASH.ordinal]      = { null,               &Compiler.binary,       FACTOR },
    [TokenType.STAR.ordinal]       = { null,               &Compiler.binary,       FACTOR },
    [TokenType.BANG.ordinal]       = { null,               null,                   NONE },
    [TokenType.BANGEQ.ordinal]     = { null,               null,                   NONE },
    [TokenType.EQUAL.ordinal]      = { null,               null,                   NONE },
    [TokenType.EQEQ.ordinal]       = { null,               null,                   NONE },
    [TokenType.GT.ordinal]         = { null,               null,                   NONE },
    [TokenType.GTEQ.ordinal]       = { null,               null,                   NONE },
    [TokenType.LT.ordinal]         = { null,               null,                   NONE },
    [TokenType.LTEQ.ordinal]       = { null,               null,                   NONE },
    [TokenType.IDENTIFIER.ordinal] = { null,               null,                   NONE },
    [TokenType.NUMBER.ordinal]     = { &Compiler.number,   null,                   NONE },
    [TokenType.STRING.ordinal]     = { null,               null,                   NONE },
    [TokenType.AND.ordinal]        = { null,               null,                   NONE },
    [TokenType.CLASS.ordinal]      = { null,               null,                   NONE },
    [TokenType.ELSE.ordinal]       = { null,               null,                   NONE },
    [TokenType.FALSE.ordinal]      = { null,               null,                   NONE },
    [TokenType.FOR.ordinal]        = { null,               null,                   NONE },
    [TokenType.FUN.ordinal]        = { null,               null,                   NONE },
    [TokenType.IF.ordinal]         = { null,               null,                   NONE },
    [TokenType.NIL.ordinal]        = { null,               null,                   NONE },
    [TokenType.OR.ordinal]         = { null,               null,                   NONE },
    [TokenType.PRINT.ordinal]      = { null,               null,                   NONE },
    [TokenType.RETURN.ordinal]     = { null,               null,                   NONE },
    [TokenType.SUPER.ordinal]      = { null,               null,                   NONE },
    [TokenType.THIS.ordinal]       = { null,               null,                   NONE },
    [TokenType.TRUE.ordinal]       = { null,               null,                   NONE },
    [TokenType.VAR.ordinal]        = { null,               null,                   NONE },
    [TokenType.WHILE.ordinal]      = { null,               null,                   NONE },
};

fn ParseRule *getRule(TokenType type)
{
    return &rules[type.ordinal];
}

fn void Parser.error(&self, Token *token, String message)
{
    if (self.panicMode) return;
    self.panicMode = true;

    io::eprintf("[line %d] Error", token.line);
    if (token.type == EOF)
        { io::eprintf(" at end"); }
    else if (token.type == ERROR)
        { /* Do nothing */ }
    else
        { io::eprintf(" at '%s'", token.lexeme); }

    io::eprintf(": %s", message);
    self.hadError = true;
}

fn void Parser.advance(&self)
{
    self.previous = self.current;

    for (;;)
    {
        self.current = self.lexer.getNextToken();
        if (self.current.type != ERROR) break;

        self.error(&self.current, self.current.lexeme);
    }
}

fn void Parser.consume(&self, TokenType type, String message)
{
    if (self.current.type == type)
    {
        self.advance();
        return;
    }

    self.error(&self.current, message);
}

//------------------------------------------------------------------------------
// Lox \ Compiler
//------------------------------------------------------------------------------

struct Compiler @public
{
    Parser parser;
    Chunk *compiling;
}

fn void Compiler.error(&self, Token *token, String message) @inline
{
    self.parser.error(token, message);
}

fn Chunk *Compiler.currentChunk(&self) @local @inline
{
    return self.compiling;
}

fn void Compiler.advance(&self) @local @inline
{
    self.parser.advance();
}

fn void Compiler.consume(&self, TokenType type, String message) @local @inline
{
    self.parser.consume(type, message);
}

fn void Compiler.emitByte(&self, char byte) @local @inline
{
    self.currentChunk().write(byte, self.parser.previous.line);
}

fn void Compiler.emitBytes(&self, char byte1, char byte2) @local
{
    self.emitByte(byte1);
    self.emitByte(byte2);
}

fn char Compiler.makeConstant(&self, Value value) @local
{
    int constant = self.currentChunk().addConstant(value);
    if (constant > char.max)
    {
        self.error(&self.parser.previous, "Too many constants in one chunk");
        return 0;
    }

    return (char)constant;
}

fn void Compiler.emitConstant(&self, Value value) @local
{
    self.emitBytes(OpCode.CONSTANT.ordinal, self.makeConstant(value));
}

fn void Compiler.emitReturn(&self) @local @inline
{
    self.emitByte(OpCode.RETURN.ordinal);
}

fn void Compiler.end(&self) @local
{
    self.emitReturn();

    $if $feature(DEBUG) &&& DEBUG_PRINT_CODE:
        if (!self.parser.hadError)
        {
            self.currentChunk().disassemble("Code");
        }
    $endif
}

fn void Compiler.grouping(&self)
{
    self.expression();
    self.consume(RPAREN, "Expected ')' after expression");
}

fn void Compiler.number(&self)
{
    double! value = self.parser.previous.lexeme.to_double();
    if (catch value)
    {
        self.error(&self.parser.previous, "Invalid number literal");
        return;
    }

    self.emitConstant(value);
}

fn void Compiler.binary(&self)
{
    TokenType operatorType = self.parser.previous.type;
    ParseRule *rule = getRule(operatorType);
    self.parsePrecedence(rule.precedence + 1);

    switch (operatorType)
    {
        case MINUS: self.emitByte(OpCode.SUBTRACT.ordinal);
        case PLUS:  self.emitByte(OpCode.ADD.ordinal);
        case SLASH: self.emitByte(OpCode.DIVIDE.ordinal);
        case STAR:  self.emitByte(OpCode.MULTIPLY.ordinal);
        default:    unreachable();
    }
}

fn void Compiler.unary(&self)
{
    TokenType operatorType = self.parser.previous.type;
    self.parsePrecedence(UNARY);

    switch (operatorType)
    {
        case MINUS: self.emitByte(OpCode.NEGATE.ordinal);
        default:    unreachable();
    }
}

fn void Compiler.parsePrecedence(&self, Precedence precedence)
{
    self.advance();

    ParseFn prefixRule = getRule(self.parser.previous.type).prefix;
    if (prefixRule == null)
    {
        self.error(&self.parser.previous, "Expected expression");
        return;
    }

    prefixRule(self);

    while (precedence <= getRule(self.parser.current.type).precedence)
    {
        self.advance();
        ParseFn infixRule = getRule(self.parser.previous.type).infix;

        infixRule(self);
    }
}

fn void Compiler.expression(&self)
{
    self.parsePrecedence(ASSIGNMENT);
}

fn bool Compiler.compile(&self, Chunk *chunk, ZString source) @public
{
    self.parser.lexer.init(source);
    self.parser.hadError = false;
    self.parser.panicMode = false;
    self.compiling = chunk;

    $if $feature(DEBUG) &&& DEBUG_DUMP_TOKENS:
        lexer::dumpTokens(&self.parser.lexer, source);
        return false;
    $endif

    self.advance();
    self.expression();
    self.consume(EOF, "Expected end of expression");

    return !self.parser.hadError;
}
