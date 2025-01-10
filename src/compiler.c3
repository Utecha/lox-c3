module lox::vm::compiler;
import lox::lexer;
import lox::token;
import lox::vm;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ VM \ Compiler -- Parser
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

def ParseFn = fn void (Compiler *compiler, bool canAssign);

struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

ParseRule[*] rules = {
    [TokenType.ERROR.ordinal]       = { null,               null,               NONE },
    [TokenType.EOF.ordinal]         = { null,               null,               NONE },
    [TokenType.LPAREN.ordinal]      = { &Compiler.grouping, null,               NONE },
    [TokenType.RPAREN.ordinal]      = { null,               null,               NONE },
    [TokenType.LBRACE.ordinal]      = { null,               null,               NONE },
    [TokenType.RBRACE.ordinal]      = { null,               null,               NONE },
    [TokenType.COMMA.ordinal]       = { null,               null,               NONE },
    [TokenType.DOT.ordinal]         = { null,               null,               NONE },
    [TokenType.SEMICOLON.ordinal]   = { null,               null,               NONE },
    [TokenType.MINUS.ordinal]       = { &Compiler.unary,    &Compiler.binary,   TERM },
    [TokenType.PLUS.ordinal]        = { null,               &Compiler.binary,   TERM },
    [TokenType.SLASH.ordinal]       = { null,               &Compiler.binary,   FACTOR },
    [TokenType.STAR.ordinal]        = { null,               &Compiler.binary,   FACTOR },
    [TokenType.BANG.ordinal]        = { &Compiler.unary,    null,               NONE },
    [TokenType.BANGEQ.ordinal]      = { null,               &Compiler.binary,   EQUALITY },
    [TokenType.EQEQ.ordinal]        = { null,               &Compiler.binary,   EQUALITY },
    [TokenType.GT.ordinal]          = { null,               &Compiler.binary,   COMPARISON },
    [TokenType.GTEQ.ordinal]        = { null,               &Compiler.binary,   COMPARISON },
    [TokenType.LT.ordinal]          = { null,               &Compiler.binary,   COMPARISON },
    [TokenType.LTEQ.ordinal]        = { null,               &Compiler.binary,   COMPARISON },
    [TokenType.EQUAL.ordinal]       = { null,               null,               NONE },
    [TokenType.IDENTIFIER.ordinal]  = { &Compiler.variable, null,               NONE },
    [TokenType.NUMBER.ordinal]      = { &Compiler.number,   null,               NONE },
    [TokenType.STRING.ordinal]      = { &Compiler.string,   null,               NONE },
    [TokenType.AND.ordinal]         = { null,               null,               NONE },
    [TokenType.CLASS.ordinal]       = { null,               null,               NONE },
    [TokenType.ELSE.ordinal]        = { null,               null,               NONE },
    [TokenType.FALSE.ordinal]       = { &Compiler.literal,  null,               NONE },
    [TokenType.FOR.ordinal]         = { null,               null,               NONE },
    [TokenType.FUN.ordinal]         = { null,               null,               NONE },
    [TokenType.IF.ordinal]          = { null,               null,               NONE },
    [TokenType.NIL.ordinal]         = { &Compiler.literal,  null,               NONE },
    [TokenType.OR.ordinal]          = { null,               null,               NONE },
    [TokenType.PRINT.ordinal]       = { null,               null,               NONE },
    [TokenType.RETURN.ordinal]      = { null,               null,               NONE },
    [TokenType.SUPER.ordinal]       = { null,               null,               NONE },
    [TokenType.THIS.ordinal]        = { null,               null,               NONE },
    [TokenType.TRUE.ordinal]        = { &Compiler.literal,  null,               NONE },
    [TokenType.VAR.ordinal]         = { null,               null,               NONE },
    [TokenType.WHILE.ordinal]       = { null,               null,               NONE },
};

fn ParseRule *getRule(TokenType type)
{
    return &rules[type.ordinal];
}

fn void Parser.errorAt(&self, Token *token, String message)
{
    if (self.panicMode) return;
    self.panicMode = true;

    io::eprintf("[line %d] Error", token.line);
    switch (token.type)
    {
        case ERROR: break;
        case EOF:   io::eprintf(" at end");
        default:    io::eprintf(" at '%s'", token.lexeme);
    }

    io::eprintfn(": %s", message);
    self.hadError = true;
}

fn void Parser.errorPrev(&self, String message)
{
    self.errorAt(&self.previous, message);
}

fn void Parser.error(&self, String message)
{
    self.errorAt(&self.current, message);
}

fn void Parser.advance(&self)
{
    self.previous = self.current;

    for (;;)
    {
        self.current = self.lexer.getNextToken();
        if (self.current.type != ERROR) break;

        self.error(self.current.lexeme);
    }
}

fn bool Parser.check(&self, TokenType type)
{
    return self.current.type == type;
}

fn void Parser.consume(&self, TokenType type, String message)
{
    if (self.current.type == type)
    {
        self.advance();
        return;
    }

    self.error(message);
}

fn bool Parser.match(&self, TokenType type)
{
    if (!self.check(type)) return false;
    self.advance();
    return true;
}

//------------------------------------------------------------------------------
// Lox \ VM \ Compiler
//------------------------------------------------------------------------------

const uint U8_COUNT = char.max + 1;

struct Local
{
    Token name;
    int depth;
}

struct Compiler
{
    LoxVM *vm;
    Chunk *chunk;
    Parser parser;
    Compiler *current;
    Local[U8_COUNT] locals;
    int localCount;
    int scopeDepth;
}

fn void Compiler.init(&self)
{
    self.current = self;
    self.localCount = 0;
    self.scopeDepth = 0;
}

fn Chunk *Compiler.currentChunk(&self)
{
    return self.chunk;
}

fn void Compiler.emitByte(&self, char byte)
{
    self.currentChunk().write(byte, self.parser.previous.line);
}

fn void Compiler.emitBytes(&self, char byte1, char byte2)
{
    self.emitByte(byte1);
    self.emitByte(byte2);
}

fn char Compiler.makeConstant(&self, Value value)
{
    int constant = self.currentChunk().addConstant(value);
    if (constant > char.max)
    {
        self.parser.error("Too many constants in one chunk");
        return 0;
    }

    return ibyte(constant);
}

fn void Compiler.emitConstant(&self, Value value)
{
    self.emitBytes(obyte(CONSTANT), self.makeConstant(value));
}

fn void Compiler.emitReturn(&self)
{
    self.emitByte(obyte(RETURN));
}

fn void Compiler.end(&self)
{
    self.emitReturn();

    $if $feature(DEBUG) &&& (debug::DUMP_CHUNK || debug::ENABLE_ALL):
        if (!self.parser.hadError)
            { self.currentChunk().disassemble("Code"); }
    $endif
}

fn void Compiler.beginScope(&self)
{
    self.current.scopeDepth++;
}

fn void Compiler.endScope(&self)
{
    self.current.scopeDepth--;

    while (self.current.localCount > 0 && self.current.locals[self.current.localCount - 1].depth > self.current.scopeDepth)
    {
        self.emitByte(obyte(POP));
        self.current.localCount--;
    }
}

fn void Compiler.grouping(&self, bool canAssign)
{
    self.expression();
    self.parser.consume(RPAREN, "Expected ')' after expression");
}

fn void Compiler.number(&self, bool canAssign)
{
    double! value = self.parser.previous.lexeme.to_double();
    if (catch value) return;

    self.emitConstant(numberVal(value));
}

fn void Compiler.literal(&self, bool canAssign)
{
    switch (self.parser.previous.type)
    {
        case NIL:   self.emitByte(obyte(NIL));
        case TRUE:  self.emitByte(obyte(TRUE));
        case FALSE: self.emitByte(obyte(FALSE));
        default:    unreachable();
    }
}

fn void Compiler.string(&self, bool canAssign)
{
    self.emitConstant(
        objVal(
            value::copyString(
                self.vm,
                self.parser.previous.lexeme[1..],
                self.parser.previous.lexeme.len - 2
            )
        )
    );
}

fn void Compiler.namedVariable(&self, Token name, bool canAssign)
{
    char getOp, setOp;
    int arg = self.current.resolveLocal(&name);
    if (arg != -1)
    {
        getOp = obyte(GET_LOCAL);
        setOp = obyte(SET_LOCAL);
    }
    else
    {
        arg = self.identifierConstant(&name);
        getOp = obyte(GET_GLOBAL);
        setOp = obyte(SET_GLOBAL);
    }

    if (canAssign && self.parser.match(EQUAL))
    {
        self.expression();
        self.emitBytes(setOp, ibyte(arg));
    }
    else
    {
        self.emitBytes(getOp, ibyte(arg));
    }
}

fn void Compiler.variable(&self, bool canAssign)
{
    self.namedVariable(self.parser.previous, canAssign);
}

fn void Compiler.binary(&self, bool canAssign)
{
    TokenType opType = self.parser.previous.type;
    ParseRule *rule = getRule(opType);
    self.parsePrecedence(rule.precedence + 1);

    switch (opType)
    {
        case BANGEQ:    self.emitBytes(obyte(EQUAL), obyte(NOT));
        case EQEQ:      self.emitByte(obyte(EQUAL));
        case GT:        self.emitByte(obyte(GREATER));
        case GTEQ:      self.emitBytes(obyte(LESS), obyte(NOT));
        case LT:        self.emitByte(obyte(LESS));
        case LTEQ:      self.emitBytes(obyte(GREATER), obyte(NOT));
        case MINUS:     self.emitByte(obyte(SUBTRACT));
        case PLUS:      self.emitByte(obyte(ADD));
        case SLASH:     self.emitByte(obyte(DIVIDE));
        case STAR:      self.emitByte(obyte(MULTIPLY));
        default:        unreachable();
    }
}

fn void Compiler.unary(&self, bool canAssign)
{
    TokenType opType = self.parser.previous.type;
    self.parsePrecedence(UNARY);

    switch (opType)
    {
        case BANG:  self.emitByte(obyte(NOT));
        case MINUS: self.emitByte(obyte(NEGATE));
        default:    unreachable();
    }
}

fn void Compiler.parsePrecedence(&self, Precedence precedence)
{
    self.parser.advance();
    ParseFn prefixRule = getRule(self.parser.previous.type).prefix;
    if (prefixRule == null)
    {
        self.parser.errorPrev("Expected expression");
        return;
    }

    bool canAssign = precedence <= Precedence.ASSIGNMENT;
    prefixRule(self, canAssign);

    while (precedence <= getRule(self.parser.current.type).precedence)
    {
        self.parser.advance();
        ParseFn infixRule = getRule(self.parser.previous.type).infix;
        infixRule(self, canAssign);
    }

    if (canAssign && self.parser.match(EQUAL))
    {
        self.parser.errorPrev("Invalid assignment target");
    }
}

fn char Compiler.identifierConstant(&self, Token *name)
{
    return self.makeConstant(objVal(value::copyString(self.vm, name.lexeme, name.lexeme.len)));
}

fn void Compiler.addLocal(&self, Token name)
{
    if (self.current.localCount == U8_COUNT)
    {
        self.parser.errorPrev("Too many local variables in function");
        return;
    }

    Local *local = &self.current.locals[self.current.localCount++];
    local.name = name;
    local.depth = -1;
}

fn bool identifiersEqual(Token *a, Token *b) @local
{
    if (a.lexeme.len != b.lexeme.len) return false;
    return mem::equals(&a.lexeme[0], &b.lexeme[0], a.lexeme.len);
}

fn int Compiler.resolveLocal(&self, Token *name)
{
    for (int i = self.localCount - 1; i >= 0; i--)
    {
        Local *local = &self.locals[i];
        if (identifiersEqual(name, &local.name))
        {
            if (local.depth == -1)
            {
                self.parser.errorPrev("Cannot read a local variable within its own initializer");
            }
            return i;
        }
    }

    return -1;
}

fn void Compiler.declareVariable(&self)
{
    if (self.current.scopeDepth == 0) return;

    Token *name = &self.parser.previous;
    for (int i = self.current.localCount - 1; i >= 0; i--)
    {
        Local *local = &self.current.locals[i];
        if (local.depth != -1 && local.depth < self.current.scopeDepth)
            { break; }

        if (identifiersEqual(name, &local.name))
            { self.parser.errorPrev("Already a variable with this name in this scope"); }
    }
    self.addLocal(*name);
}

fn char Compiler.parseVariable(&self, String message)
{
    self.parser.consume(IDENTIFIER, message);

    self.declareVariable();
    if (self.current.scopeDepth > 0) return 0;

    return self.identifierConstant(&self.parser.previous);
}

fn void Compiler.markInitialized(&self)
{
    self.current.locals[self.current.localCount - 1].depth = self.current.scopeDepth;
}

fn void Compiler.defineVariable(&self, char global)
{
    if (self.current.scopeDepth > 0)
    {
        self.markInitialized();
        return;
    }

    self.emitBytes(obyte(DEFINE_GLOBAL), global);
}

fn void Compiler.expression(&self)
{
    self.parsePrecedence(ASSIGNMENT);
}

fn void Compiler.block(&self)
{
    while (!self.parser.check(RBRACE) && !self.parser.check(EOF))
    {
        self.declaration();
    }

    self.parser.consume(RBRACE, "Expected '}' after block");
}

fn void Compiler.expressionStatement(&self)
{
    self.expression();
    self.parser.consume(SEMICOLON, "Expected ';' after expression");
    self.emitByte(obyte(POP));
}

fn void Compiler.printStatement(&self)
{
    self.expression();
    self.parser.consume(SEMICOLON, "Expected ';' after value");
    self.emitByte(obyte(PRINT));
}

fn void Compiler.statement(&self)
{
    switch
    {
        case self.parser.match(PRINT):
            self.printStatement();
        case self.parser.match(LBRACE):
        {
            self.beginScope();
            self.block();
            self.endScope();
        }
        default:
            self.expressionStatement();
    }
}

fn void Compiler.varDeclaration(&self)
{
    char global = self.parseVariable("Expected variable name");

    if (self.parser.match(EQUAL))
        { self.expression(); }
    else
        { self.emitByte(obyte(NIL)); }

    self.parser.consume(SEMICOLON, "Expected ';' after variable declaration");
    self.defineVariable(global);
}

fn void Compiler.declaration(&self)
{
    switch
    {
        case self.parser.match(VAR):
            self.varDeclaration();
        default:
            self.statement();
    }

    if (self.parser.panicMode) self.synchronize();
}

fn void Compiler.synchronize(&self)
{
    self.parser.panicMode = false;

    while (self.parser.current.type != EOF)
    {
        if (self.parser.previous.type == SEMICOLON) return;
        switch (self.parser.current.type)
        {
            case CLASS:
            case FOR:
            case FUN:
            case IF:
            case PRINT:
            case RETURN:
            case VAR:
            case WHILE:
                return;
            default:
                ; // Do nothing
        }

        self.parser.advance();
    }
}

fn bool compile(LoxVM *vm, Chunk *chunk, char *source)
{
    Lexer lexer;
    lexer.init(source);

    Parser parser;
    parser.lexer = lexer;
    parser.hadError = false;
    parser.panicMode = false;

    Compiler compiler;
    compiler.vm = vm;
    compiler.chunk = chunk;
    compiler.parser = parser;
    compiler.init();

    compiler.parser.advance();

    while (!compiler.parser.match(EOF))
    {
        compiler.declaration();
    }

    compiler.end();
    return !compiler.parser.hadError;
}
