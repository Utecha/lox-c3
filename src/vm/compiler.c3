module lox::vm::compiler;
import lox::debug, lox::lexer, lox::token;
import lox::cli::utils, lox::vm;

//------------------------------------------------------------------------------
// Lox | VM | Compiler @Parser
//------------------------------------------------------------------------------

struct Parser
{
    Lexer lexer;
    Token current;
    Token previous;
    bool error;
    bool panicking;
}

fn void Parser.error_at(&self, Token *token, String message)
{
    if (self.panicking) return;
    self.panicking = true;

    utils::log(
        ERROR,
        "{ %sfile%s %s%s%s : %sline%s %d }",
        utils::BLUE, utils::RESET,
        utils::GREEN, self.lexer.file, utils::RESET,
        utils::BLUE, utils::RESET, token.line
    );

    switch (token.type)
    {
        case ERROR:     break;
        case EOF:       utils::log(NONE, " at EOF");
        case STRING:    utils::log(NONE, " at %s", token.lexeme);
        default:        utils::log(NONE, " at '%s'", token.lexeme);
    }

    utils::logn(NONE, ": %s", message);
    self.error = true;
}

macro Parser.@eprevious(&self, String message)
{
    self.error_at(&self.previous, message);
}

macro Parser.@ecurrent(&self, String message)
{
    self.error_at(&self.current, message);
}

fn void Parser.advance(&self)
{
    self.previous = self.current;

    for (;;)
    {
        self.current = self.lexer.next_token();
        if (self.current.type != ERROR) break;

        self.@ecurrent(self.current.lexeme);
    }
}

fn bool Parser.check(&self, TokenType type)
{
    return self.current.type == type;
}

fn bool Parser.match(&self, TokenType type)
{
    if (!self.check(type)) return false;
    self.advance();
    return true;
}

fn void Parser.consume(&self, TokenType type, String message)
{
    if (self.current.type == type)
    {
        self.advance();
        return;
    }

    self.@ecurrent(message);
}

//------------------------------------------------------------------------------
// Lox | VM | Compiler @ParseRule
//------------------------------------------------------------------------------

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

def ParseFn = fn void (Compiler *compiler, bool can_assign);

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
    [TokenType.MODULUS.ordinal]     = { null,               &Compiler.binary,   FACTOR },
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
    [TokenType.AND.ordinal]         = { null,               &Compiler.and,      AND },
    [TokenType.CLASS.ordinal]       = { null,               null,               NONE },
    [TokenType.ELSE.ordinal]        = { null,               null,               NONE },
    [TokenType.FALSE.ordinal]       = { &Compiler.literal,  null,               NONE },
    [TokenType.FOR.ordinal]         = { null,               null,               NONE },
    [TokenType.FUN.ordinal]         = { null,               null,               NONE },
    [TokenType.IF.ordinal]          = { null,               null,               NONE },
    [TokenType.NIL.ordinal]         = { &Compiler.literal,  null,               NONE },
    [TokenType.OR.ordinal]          = { null,               &Compiler.or,       OR },
    [TokenType.PRINT.ordinal]       = { null,               null,               NONE },
    [TokenType.RETURN.ordinal]      = { null,               null,               NONE },
    [TokenType.SUPER.ordinal]       = { null,               null,               NONE },
    [TokenType.THIS.ordinal]        = { null,               null,               NONE },
    [TokenType.TRUE.ordinal]        = { &Compiler.literal,  null,               NONE },
    [TokenType.VAR.ordinal]         = { null,               null,               NONE },
    [TokenType.WHILE.ordinal]       = { null,               null,               NONE },
};

fn ParseRule *get_rule(TokenType type)
{
    return &rules[type.ordinal];
}

//------------------------------------------------------------------------------
// Lox | VM | Compiler @public
//------------------------------------------------------------------------------

const uint U8_COUNT = char.max + 1;

struct Compiler
{
    Vm *vm;
    Parser parser;
    Chunk *chunk;
    Local[U8_COUNT] locals;
    int local_count;
    int scope_depth;
}

fn bool compile(Vm *vm, String file, Chunk *chunk, char *source)
{
    Lexer lexer;
    lexer.init(file, source);

    Parser parser;
    parser.lexer = lexer;
    parser.error = false;
    parser.panicking = false;

    Compiler compiler;
    compiler.vm = vm;
    compiler.parser = parser;
    compiler.chunk = chunk;
    compiler.init();

    compiler.parser.advance();
    while (!compiler.parser.match(EOF))
        { compiler.declaration(); }

    compiler.end();
    return !compiler.parser.error;
}

//------------------------------------------------------------------------------
// Lox | VM | Compiler @public
//------------------------------------------------------------------------------

struct Local
{
    Token name;
    int depth;
}

fn void Compiler.init(&self)
{
    self.local_count = 0;
    self.scope_depth = 0;
}

macro Chunk *Compiler.@current(&self)
{
    return self.chunk;
}

fn void Compiler.emit_byte(&self, char byte)
{
    self.@current().write(byte, self.parser.previous.line);
}

fn void Compiler.emit_bytes(&self, char byte1, char byte2)
{
    self.emit_byte(byte1);
    self.emit_byte(byte2);
}

fn void Compiler.patch_jump(&self, int offset)
{
    int jump = self.@current().code.len() - offset - 2;
    if (jump > ushort.max)
    {
        self.parser.@eprevious("Too much code to jump over");
    }

    self.@current().code[offset] = ibyte((jump >> 8) & 0xff);
    self.@current().code[offset + 1] = ibyte(jump & 0xff);
}

fn int Compiler.emit_jump(&self, char instruction)
{
    self.emit_byte(instruction);
    self.emit_byte(0xff);
    self.emit_byte(0xff);
    return self.@current().code.len() - 2;
}

fn void Compiler.emit_loop(&self, int loop_start)
{
    self.emit_byte(obyte(LOOP));

    int offset = self.@current().code.len() - loop_start + 2;
    if (offset > ushort.max)
    {
        self.parser.@eprevious("Loop body is too large");
    }

    self.emit_byte(ibyte((offset >> 8) & 0xff));
    self.emit_byte(ibyte(offset & 0xff));
}

fn char Compiler.make_constant(&self, Value value)
{
    int constant = self.@current().add_constant(value);
    if (constant > char.max)
    {
        self.parser.@ecurrent("Too many constants in one chunk");
        return 0;
    }

    return ibyte(constant);
}

fn void Compiler.emit_constant(&self, Value value)
{
    self.emit_bytes(obyte(CONSTANT), self.make_constant(value));
}

fn void Compiler.emit_return(&self)
{
    self.emit_byte(obyte(RETURN));
}

fn void Compiler.end(&self)
{
    self.emit_return();

    $if $feature(DEBUG) &&& (debug::DUMP_CHUNK ||| debug::ENABLE_ALL):
        if (!self.parser.error)
            { self.@current().disassemble("Code"); }
    $endif
}

fn void Compiler.begin_scope(&self)
{
    self.scope_depth++;
}

fn void Compiler.end_scope(&self)
{
    self.scope_depth--;
    while (self.local_count > 0 && self.locals[self.local_count - 1].depth > self.scope_depth)
    {
        self.emit_byte(obyte(POP));
        self.local_count--;
    }
}

fn void Compiler.grouping(&self, bool can_assign)
{
    self.expression();
    self.parser.consume(RPAREN, "Expected ')' after expression");
}

fn void Compiler.number(&self, bool can_assign)
{
    double! value = self.parser.previous.lexeme.to_double();
    if (catch value) return;

    self.emit_constant(number_val(value));
}

fn void Compiler.literal(&self, bool can_assign)
{
    switch (self.parser.previous.type)
    {
        case NIL:   self.emit_byte(obyte(NIL));
        case TRUE:  self.emit_byte(obyte(TRUE));
        case FALSE: self.emit_byte(obyte(FALSE));
        default:    return;
    }
}

fn void Compiler.string(&self, bool can_assign)
{
    self.emit_constant(
        obj_val(
            value::copy_string(
                self.vm,
                self.parser.previous.lexeme[1..],
                self.parser.previous.lexeme.len - 2
            )
        )
    );
}

fn void Compiler.named_variable(&self, Token name, bool can_assign)
{
    char getOp, setOp;

    int arg = self.resolve_local(&name);
    if (arg != -1)
    {
        getOp = obyte(GET_LOCAL);
        setOp = obyte(SET_LOCAL);
    }
    else
    {
        arg = self.identifier_constant(&name);
        getOp = obyte(GET_GLOBAL);
        setOp = obyte(SET_GLOBAL);
    }

    if (can_assign && self.parser.match(EQUAL))
    {
        self.expression();
        self.emit_bytes(setOp, ibyte(arg));
    }
    else
    {
        self.emit_bytes(getOp, ibyte(arg));
    }
}

fn void Compiler.binary(&self, bool can_assign)
{
    TokenType op_type = self.parser.previous.type;
    ParseRule *rule = get_rule(op_type);
    self.parse_precedence(rule.precedence + 1);

    switch (op_type)
    {
        case BANGEQ:    self.emit_bytes(obyte(EQUAL), obyte(NOT));
        case EQEQ:      self.emit_byte(obyte(EQUAL));
        case GT:        self.emit_byte(obyte(GREATER));
        case GTEQ:      self.emit_bytes(obyte(LESS), obyte(NOT));
        case LT:        self.emit_byte(obyte(LESS));
        case LTEQ:      self.emit_bytes(obyte(GREATER), obyte(NOT));
        case MINUS:     self.emit_byte(obyte(SUBTRACT));
        case PLUS:      self.emit_byte(obyte(ADD));
        case SLASH:     self.emit_byte(obyte(DIVIDE));
        case STAR:      self.emit_byte(obyte(MULTIPLY));
        case MODULUS:   self.emit_byte(obyte(MODULO));
        default:        return;
    }
}

fn void Compiler.unary(&self, bool can_assign)
{
    TokenType op_type = self.parser.previous.type;
    self.parse_precedence(UNARY);

    switch (op_type)
    {
        case BANG:  self.emit_byte(obyte(NOT));
        case MINUS: self.emit_byte(obyte(NEGATE));
        default:    return;
    }
}

fn void Compiler.variable(&self, bool can_assign)
{
    self.named_variable(self.parser.previous, can_assign);
}

fn void Compiler.and(&self, bool can_assign)
{
    int end_jump = self.emit_jump(obyte(JUMP_IF_FALSE));
    self.emit_byte(obyte(POP));
    self.parse_precedence(AND);
    self.patch_jump(end_jump);
}

fn void Compiler.or(&self, bool can_assign)
{
    int end_jump = self.emit_jump(obyte(JUMP_IF_TRUE));
    self.emit_byte(obyte(POP));
    self.parse_precedence(OR);
    self.patch_jump(end_jump);
}

fn char Compiler.identifier_constant(&self, Token *name)
{
    return self.make_constant(
        obj_val(value::copy_string(self.vm, name.lexeme, name.lexeme.len))
    );
}

fn bool identifiers_equal(Token *a, Token *b)
{
    if (a.lexeme.len != b.lexeme.len) return false;
    return mem::equals(a.lexeme.ptr, b.lexeme.ptr, a.lexeme.len);
}

fn void Compiler.add_local(&self, Token name)
{
    if (self.local_count == U8_COUNT)
    {
        self.parser.@eprevious("Too many local variables in scope");
        return;
    }

    Local *local = &self.locals[self.local_count++];
    local.name = name;
    local.depth = -1;
}

fn int Compiler.resolve_local(&self, Token *name)
{
    for (int i = self.local_count - 1; i >= 0; i--)
    {
        Local *local = &self.locals[i];
        if (identifiers_equal(name, &local.name))
        {
            if (local.depth == -1)
            {
                self.parser.@eprevious("Cannot read a local variable within its own initializer");
            }

            return i;
        }
    }

    return -1;
}

fn void Compiler.parse_precedence(&self, Precedence precedence)
{
    self.parser.advance();
    ParseFn prefix_rule = get_rule(self.parser.previous.type).prefix;
    if (prefix_rule == null)
    {
        self.parser.@eprevious("Expected expression");
        return;
    }

    bool can_assign = precedence <= Precedence.ASSIGNMENT;
    prefix_rule(self, can_assign);

    while (precedence <= get_rule(self.parser.current.type).precedence)
    {
        self.parser.advance();
        ParseFn infix_rule = get_rule(self.parser.previous.type).infix;
        infix_rule(self, can_assign);
    }

    if (can_assign && self.parser.match(EQUAL))
    {
        self.parser.@eprevious("Invalid assignment target");
    }
}

fn void Compiler.expression(&self)
{
    self.parse_precedence(ASSIGNMENT);
}

fn void Compiler.declare_variable(&self)
{
    if (self.scope_depth == 0) return;

    Token *name = &self.parser.previous;
    for (int i = self.local_count - 1; i >= 0; i--)
    {
        Local *local = &self.locals[i];
        if (local.depth != -1 && local.depth < self.scope_depth)
            { break; }

        if (identifiers_equal(name, &local.name))
            { self.parser.@eprevious("Already a variable with this name in this scope"); }
    }

    self.add_local(*name);
}

fn char Compiler.parse_variable(&self, String message)
{
    self.parser.consume(IDENTIFIER, message);
    self.declare_variable();
    if (self.scope_depth > 0) return 0;
    return self.identifier_constant(&self.parser.previous);
}

fn void Compiler.mark_initialized(&self)
{
    self.locals[self.local_count - 1].depth = self.scope_depth;
}

fn void Compiler.define_variable(&self, char global)
{
    if (self.scope_depth > 0)
    {
        self.mark_initialized();
        return;
    }

    self.emit_bytes(obyte(DEFINE_GLOBAL), global);
}

fn void Compiler.block(&self)
{
    while (!self.parser.check(RBRACE) && !self.parser.check(EOF))
        { self.declaration(); }

    self.parser.consume(RBRACE, "Expected '}' after block");
}

fn void Compiler.expr_statement(&self)
{
    if (!self.parser.check(SEMICOLON))
    {
        self.expression();
        self.parser.consume(SEMICOLON, "Expected ';' after expression");
        self.emit_byte(obyte(POP));
        return;
    }

    self.parser.advance();
}

fn void Compiler.for_statement(&self)
{
    self.begin_scope();

    self.parser.consume(LPAREN, "Expected '(' after 'for'");
    if (self.parser.match(SEMICOLON))
        { /* No initializer */ }
    else if (self.parser.match(VAR))
        { self.var_declaration(); }
    else
        { self.expr_statement(); }

    int loop_start = self.@current().code.len();
    int exit_jump = -1;

    if (!self.parser.match(SEMICOLON))
    {
        self.expression();
        self.parser.consume(SEMICOLON, "Expected ';' after 'for' condition");

        // Jump out of the loop if the condition is false
        exit_jump = self.emit_jump(obyte(JUMP_IF_FALSE));
        self.emit_byte(obyte(POP));
    }

    if (!self.parser.match(RPAREN))
    {
        int body_jump = self.emit_jump(obyte(JUMP));
        int increment_start = self.@current().code.len();

        self.expression();
        self.emit_byte(obyte(POP));
        self.parser.consume(RPAREN, "Expected ')' after 'for' loop increment value");

        self.emit_loop(loop_start);
        loop_start = increment_start;
        self.patch_jump(body_jump);
    }

    self.statement();
    self.emit_loop(loop_start);

    if (exit_jump != -1)
    {
        self.patch_jump(exit_jump);
        self.emit_byte(obyte(POP)); // Condition
    }

    self.end_scope();
}

fn void Compiler.if_statement(&self)
{
    self.parser.consume(LPAREN, "Expected '(' after 'if'");
    self.expression();
    self.parser.consume(RPAREN, "Expected ')' after 'if' condition");

    int then_jump = self.emit_jump(obyte(JUMP_IF_FALSE));
    self.emit_byte(obyte(POP));
    self.statement();

    int else_jump = self.emit_jump(obyte(JUMP));
    self.patch_jump(then_jump);
    self.emit_byte(obyte(POP));

    if (self.parser.match(ELSE)) self.statement();
    self.patch_jump(else_jump);
}

fn void Compiler.print_statement(&self)
{
    self.expression();
    self.parser.consume(SEMICOLON, "Expected ';' after value");
    self.emit_byte(obyte(PRINT));
}

fn void Compiler.while_statement(&self)
{
    int loop_start = self.@current().code.len();

    self.parser.consume(LPAREN, "Expected '(' after 'while'");
    self.expression();
    self.parser.consume(RPAREN, "Expected ')' after 'while' condition");

    int exit_jump = self.emit_jump(obyte(JUMP_IF_FALSE));
    self.emit_byte(obyte(POP));
    self.statement();
    self.emit_loop(loop_start);

    self.patch_jump(exit_jump);
    self.emit_byte(obyte(POP));
}

fn void Compiler.statement(&self)
{
    switch
    {
        case self.parser.match(IF):
            self.if_statement();
        case self.parser.match(FOR):
            self.for_statement();
        case self.parser.match(PRINT):
            self.print_statement();
        case self.parser.match(WHILE):
            self.while_statement();
        case self.parser.match(LBRACE):
        {
            self.begin_scope();
            self.block();
            self.end_scope();
        }
        default:
            self.expr_statement();
    }
}

fn void Compiler.var_declaration(&self)
{
    char global = self.parse_variable("Expected variable name");

    if (self.parser.match(EQUAL))
        { self.expression(); }
    else
        { self.emit_byte(obyte(NIL)); }

    self.parser.consume(SEMICOLON, "Expected ';' after variable declaration");
    self.define_variable(global);
}

fn void Compiler.declaration(&self)
{
    switch
    {
        case self.parser.match(VAR):
            self.var_declaration();
        default:
            self.statement();
    }

    if (self.parser.panicking) self.synchronize();
}

fn void Compiler.synchronize(&self)
{
    self.parser.panicking = false;

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