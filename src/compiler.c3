module lox::compiler @private;
import lox::chunk, lox::lexer, lox::value, lox::vm;
import std::io @norecurse;

const uint MAX_LOCALS = (1 << 8);
const uint MAX_UPVALUES = (1 << 8);
const uint MAX_JUMP = (1 << 16);

ClassCompiler *current_class;

alias ParseFn = fn void (Compiler *self, bool can_assign);

enum FunctionType : inline int
{
    FUNCTION,
    METHOD,
    INITIALIZER,
    SCRIPT
}

enum Precedence : inline int
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

struct Parser
{
    LoxVM *vm;
    Lexer *lexer;
    Token current;
    Token previous;
    bool had_error;
    bool panic_mode;
}

struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

struct Local
{
    Token name;
    int depth;
    bool is_captured;
}

struct Upvalue
{
    char index;
    bool is_local;
}

struct ClassCompiler
{
    ClassCompiler *enclosing;
    bool has_superclass;
}

struct Compiler @public
{
    Parser *parser;
    Compiler *parent;
    ObjFn *function;
    FunctionType type;
    Local[MAX_LOCALS] locals;
    int local_count;
    Upvalue[MAX_UPVALUES] upvalues;
    int scope_depth;
}

ParseRule[] rules = {
    [TokenType.LPAREN.ordinal]      = { &grouping,  &call,      CALL },
    [TokenType.RPAREN.ordinal]      = { null,       null,       NONE },
    [TokenType.LBRACE.ordinal]      = { null,       null,       NONE },
    [TokenType.RBRACE.ordinal]      = { null,       null,       NONE },
    [TokenType.COMMA.ordinal]       = { null,       null,       NONE },
    [TokenType.DOT.ordinal]         = { null,       &dot,       CALL },
    [TokenType.SEMICOLON.ordinal]   = { null,       null,       NONE },
    [TokenType.MINUS.ordinal]       = { &unary,     &binary,    TERM },
    [TokenType.PLUS.ordinal]        = { null,       &binary,    TERM },
    [TokenType.SLASH.ordinal]       = { null,       &binary,    FACTOR },
    [TokenType.STAR.ordinal]        = { null,       &binary,    FACTOR },
    [TokenType.EQUAL.ordinal]       = { null,       null,       NONE },
    [TokenType.EQEQ.ordinal]        = { null,       &binary,    EQUALITY },
    [TokenType.NOT.ordinal]         = { &unary,     null,       NONE },
    [TokenType.NOTEQ.ordinal]       = { null,       &binary,    EQUALITY },
    [TokenType.GT.ordinal]          = { null,       &binary,    COMPARISON },
    [TokenType.GTEQ.ordinal]        = { null,       &binary,    COMPARISON },
    [TokenType.LT.ordinal]          = { null,       &binary,    COMPARISON },
    [TokenType.LTEQ.ordinal]        = { null,       &binary,    COMPARISON },
    [TokenType.IDENTIFIER.ordinal]  = { &variable,  null,       NONE },
    [TokenType.NUMBER.ordinal]      = { &number,    null,       NONE },
    [TokenType.STRING.ordinal]      = { &string,    null,       NONE },
    [TokenType.AND.ordinal]         = { null,       &and_,      AND },
    [TokenType.CLASS.ordinal]       = { null,       null,       NONE },
    [TokenType.ELSE.ordinal]        = { null,       null,       NONE },
    [TokenType.FALSE.ordinal]       = { &literal,   null,       NONE },
    [TokenType.FOR.ordinal]         = { null,       null,       NONE },
    [TokenType.FUN.ordinal]         = { null,       null,       NONE },
    [TokenType.IF.ordinal]          = { null,       null,       NONE },
    [TokenType.NIL.ordinal]         = { &literal,   null,       NONE },
    [TokenType.OR.ordinal]          = { null,       &or_,       OR },
    [TokenType.PRINT.ordinal]       = { null,       null,       NONE },
    [TokenType.RETURN.ordinal]      = { null,       null,       NONE },
    [TokenType.SUPER.ordinal]       = { &super,     null,       NONE },
    [TokenType.THIS.ordinal]        = { &this,      null,       NONE },
    [TokenType.TRUE.ordinal]        = { &literal,   null,       NONE },
    [TokenType.VAR.ordinal]         = { null,       null,       NONE },
    [TokenType.WHILE.ordinal]       = { null,       null,       NONE },
    [TokenType.ERROR.ordinal]       = { null,       null,       NONE },
    [TokenType.EOF.ordinal]         = { null,       null,       NONE },
};

// Parser ----------------------------------------------------------------------

fn void Parser.init(&self, LoxVM *vm, Lexer *lexer)
{
    self.vm = vm;
    self.lexer = lexer;
    self.had_error = false;
}

fn void Parser.error_at(&self, Token *token, String message)
{
    if (self.panic_mode) return;
    self.panic_mode = true;

    io::printf("[line %d] Error", token.line);
    switch (token.type)
    {
        case EOF:   io::print(" at end");
        case ERROR: break;
        default:    io::printf(" at '%s'", token.lexeme);
    }

    io::printfn(": %s", message);
    self.had_error = true;
}

fn void Parser.error(&self, String message)
{
    self.error_at(&self.previous, message);
}

fn void Parser.error_at_current(&self, String message)
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

        self.error_at_current(self.current.lexeme);
    }
}

fn bool Parser.check(&self, TokenType type)
{
    return self.current.type == type;
}

fn void Parser.consume(&self, TokenType type, String message)
{
    if (self.check(type))
    {
        self.advance();
        return;
    }

    self.error_at_current(message);
}

fn bool Parser.match(&self, TokenType type)
{
    if (!self.check(type)) return false;
    self.advance();
    return true;
}

fn void Parser.synchronize(&self)
{
    self.panic_mode = false;

    while (self.current.type != EOF)
    {
        if (self.previous.type == SEMICOLON) return;
        switch (self.current.type)
        {
            case CLASS:
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

        self.advance();
    }
}

// Compiler --------------------------------------------------------------------

fn void Compiler.init(&self, Parser *parser, Compiler *parent, FunctionType type)
{
    self.parser = parser;
    self.parent = parent;
    self.function = null;
    self.type = type;
    self.local_count = 0;
    self.scope_depth = 0;
    self.function = value::new_function(self.parser.vm);
    self.parser.vm.compiler = self;

    if (type != SCRIPT)
    {
        self.function.name = value::copy_string(
            self.parser.vm,
            self.parser.previous.lexeme,
            self.parser.previous.length
        );
    }

    Local *local = &self.locals[self.local_count++];
    local.depth = 0;
    local.is_captured = false;

    if (type != FUNCTION)
    {
        local.name.lexeme = "this";
        local.name.length = 4;
    }
    else
    {
        local.name.lexeme = "";
        local.name.length = 0;
    }
}

fn Chunk *Compiler.current_chunk(&self)
{
    return &self.function.chunk;
}

fn void Compiler.emit_byte(&self, int byte)
{
    self.current_chunk().write(self.parser.vm, ibyte(byte), self.parser.previous.line);
}

fn void Compiler.emit_op(&self, OpCode instruction)
{
    self.current_chunk().write(self.parser.vm, obyte(instruction), self.parser.previous.line);
}

fn void Compiler.emit_ops(&self, OpCode instruction1, OpCode instruction2)
{
    self.emit_op(instruction1);
    self.emit_op(instruction2);
}

fn void Compiler.emit_op_byte(&self, OpCode instruction, int byte)
{
    self.emit_op(instruction);
    self.emit_byte(byte);
}

fn int Compiler.make_constant(&self, Value value)
{
    int constant = self.current_chunk().add_constant(self.parser.vm, value);
    if (constant > char.max)
    {
        self.parser.error("Too many constants in one chunk");
        return 0;
    }

    return (char)constant;
}

fn void Compiler.emit_constant(&self, Value value)
{
    self.emit_op_byte(CONSTANT, self.make_constant(value));
}

fn void Compiler.emit_return(&self)
{
    if (self.type == INITIALIZER)
    {
        self.emit_op_byte(GET_LOCAL, 0);
    }
    else
    {
        self.emit_op(NIL);
    }

    self.emit_op(RETURN);
}

fn int Compiler.emit_jump(&self, OpCode instruction)
{
    self.emit_op(instruction);
    self.emit_byte(0xff);
    self.emit_byte(0xff);
    return self.current_chunk().code.len() - 2;
}

fn void Compiler.patch_jump(&self, int offset)
{
    int jump = self.current_chunk().code.len() - offset - 2;
    if (jump > MAX_JUMP)
    {
        self.parser.error("Too much code to jump over");
    }

    self.current_chunk().code[offset] = ibyte((jump >> 8) & 0xff);
    self.current_chunk().code[offset + 1] = ibyte(jump & 0xff);
}

fn void Compiler.emit_loop(&self, int loop_start)
{
    self.emit_op(LOOP);

    int offset = self.current_chunk().code.len() - loop_start + 2;
    if (offset > MAX_JUMP)
    {
        self.parser.error("Loop body is too large");
    }

    self.emit_byte((offset >> 8) & 0xff);
    self.emit_byte(offset & 0xff);
}

fn ObjFn *Compiler.end(&self)
{
    self.emit_return();
    ObjFn *function = self.function;

    $if $feature(DEBUG) &&& vm::DUMP_CODE:
        if (!self.parser.had_error)
        {
            self.current_chunk().disassemble(
                function.name == null ?
                    "<script>" : (String)function.name.value[:function.name.length]
            );
        }
    $endif

    self.parser.vm.compiler = self.parent;
    return function;
}

fn int Compiler.identifier_constant(&self, Token *name)
{
    return self.make_constant(make_obj(value::copy_string(self.parser.vm, name.lexeme, name.length)));
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
        if (self.locals[self.local_count - 1].is_captured)
        {
            self.emit_op(CLOSE_UPVALUE);
        }
        else
        {
            self.emit_op(POP);
        }

        self.local_count--;
    }
}

macro @scope(compiler; @body)
{
    compiler.begin_scope();
    defer compiler.end_scope();
    @body();
}

fn void Compiler.parse_precedence(&self, Precedence precedence)
{
    self.parser.advance();
    ParseFn prefix_rule = get_rule(self.parser.previous.type).prefix;
    if (prefix_rule == null)
    {
        self.parser.error("Expected expression");
        return;
    }

    bool can_assign = precedence <= ASSIGNMENT;
    prefix_rule(self, can_assign);

    while (precedence <= get_rule(self.parser.current.type).precedence)
    {
        self.parser.advance();
        ParseFn infix_rule = get_rule(self.parser.previous.type).infix;
        infix_rule(self, can_assign);
    }

    if (self.parser.match(EQUAL) && can_assign)
    {
        self.parser.error("Invalid assignment target");
    }
}

fn void Compiler.expression(&self)
{
    self.parse_precedence(ASSIGNMENT);
}

fn void Compiler.block(&self)
{
    while (!self.parser.check(RBRACE) && !self.parser.check(EOF))
    {
        self.declaration();
    }

    self.parser.consume(RBRACE, "Expected '}' after block");
}

fn void Compiler.expression_statement(&self)
{
    self.expression();
    self.parser.consume(SEMICOLON, "Expected ';' after expression");
    self.emit_op(POP);
}

fn void Compiler.for_statement(&self)
{
    @scope(self)
    {
        self.parser.consume(LPAREN, "Expected '(' after 'for'");
        if (self.parser.match(SEMICOLON))
        {
            // No initializer
        }
        else if (self.parser.match(VAR))
        {
            self.var_declaration();
        }
        else
        {
            self.expression_statement();
        }

        int loop_start = self.current_chunk().code.len();
        int exit_jump = -1;

        if (!self.parser.match(SEMICOLON))
        {
            self.expression();
            self.parser.consume(SEMICOLON, "Expected ';' after 'for' condition");

            exit_jump = self.emit_jump(JUMP_IF);
            self.emit_op(POP); // Condition
        }

        if (!self.parser.match(RPAREN))
        {
            int body_jump = self.emit_jump(JUMP);
            int increment_start = self.current_chunk().code.len();

            self.expression();
            self.emit_op(POP);
            self.parser.consume(RPAREN, "Expected ')' after 'for' clauses");

            self.emit_loop(loop_start);
            loop_start = increment_start;
            self.patch_jump(body_jump);
        }

        self.statement();
        self.emit_loop(loop_start);

        if (exit_jump != -1)
        {
            self.patch_jump(exit_jump);
            self.emit_op(POP);
        }
    };
}

fn void Compiler.fun_statement(&self, FunctionType type)
{
    Compiler fun_compiler;
    fun_compiler.init(self.parser, self, type);
    fun_compiler.begin_scope();

    Parser *parser = fun_compiler.parser;
    parser.consume(LPAREN, "Expected '(' after function name");

    if (!parser.check(RPAREN))
    {
        do
        {
            fun_compiler.function.arity++;
            if (fun_compiler.function.arity > 255)
            {
                parser.error_at_current("Cannot have more than 255 parameters to a function");
            }

            int constant = fun_compiler.parse_variable("Expected parameter name");
            fun_compiler.define_variable(constant);
        } while (parser.match(COMMA));
    }

    parser.consume(RPAREN, "Expected ')' after function parameters");
    parser.consume(LBRACE, "Expected '{' before function body");
    fun_compiler.block();

    ObjFn *function = fun_compiler.end();
    self.emit_op_byte(CLOSURE, self.make_constant(make_obj(function)));

    for (int i = 0; i < function.upvalue_count; i++)
    {
        self.emit_byte(fun_compiler.upvalues[i].is_local ? 1 : 0);
        self.emit_byte(fun_compiler.upvalues[i].index);
    }
}

fn void Compiler.if_statement(&self)
{
    self.parser.consume(LPAREN, "Expected '(' after 'if'");
    self.expression();
    self.parser.consume(RPAREN, "Expected '(' after 'if' condition");

    int then_jump = self.emit_jump(JUMP_IF);
    self.emit_op(POP);
    self.statement();

    int else_jump = self.emit_jump(JUMP);
    self.patch_jump(then_jump);
    self.emit_op(POP);

    if (self.parser.match(ELSE)) self.statement();
    self.patch_jump(else_jump);
}

fn void Compiler.method(&self)
{
    self.parser.consume(IDENTIFIER, "Expected method name");
    int constant = self.identifier_constant(&self.parser.previous);

    FunctionType type = METHOD;
    String init_string = "init";
    if (self.parser.previous.length == 4 &&
        mem::equals(&self.parser.previous.lexeme[0], &init_string[0], 4))
    {
        type = INITIALIZER;
    }

    self.fun_statement(type);
    self.emit_op_byte(METHOD, constant);
}

fn void Compiler.print_statement(&self)
{
    self.expression();
    self.parser.consume(SEMICOLON, "Expected ';' after 'print' value");
    self.emit_op(PRINT);
}

fn void Compiler.return_statement(&self)
{
    if (self.type == SCRIPT)
    {
        self.parser.error("Cannot return from top-level code");
    }

    if (self.parser.match(SEMICOLON))
    {
        self.emit_return();
    }
    else
    {
        if (self.type == INITIALIZER)
        {
            self.parser.error("Cannot return a value from an initializer method");
        }

        self.expression();
        self.parser.consume(SEMICOLON, "Expected ';' after 'return' value");
        self.emit_op(RETURN);
    }
}

fn void Compiler.while_statement(&self)
{
    int loop_start = self.current_chunk().code.len();

    self.parser.consume(LPAREN, "Expected '(' after 'while'");
    self.expression();
    self.parser.consume(RPAREN, "Expected '(' after 'while' condition");

    int exit_jump = self.emit_jump(JUMP_IF);
    self.emit_op(POP);
    self.statement();
    self.emit_loop(loop_start);

    self.patch_jump(exit_jump);
    self.emit_op(POP);
}

fn void Compiler.statement(&self)
{
    switch
    {
        case self.parser.match(FOR):
            self.for_statement();

        case self.parser.match(IF):
            self.if_statement();

        case self.parser.match(PRINT):
            self.print_statement();

        case self.parser.match(RETURN):
            self.return_statement();

        case self.parser.match(WHILE):
            self.while_statement();

        case self.parser.match(LBRACE):
            @scope(self) { self.block(); };

        default:
            self.expression_statement();
    }
}

fn void Compiler.add_local(&self, Token name)
{
    if (self.local_count == MAX_LOCALS)
    {
        self.parser.error("Too many local variables in scope");
        return;
    }

    Local *local = &self.locals[self.local_count++];
    local.name = name;
    local.depth = -1;
    local.is_captured = false;
}

fn int Compiler.add_upvalue(&self, char index, bool is_local)
{
    int upvalue_count = self.function.upvalue_count;

    for (int i = 0; i < upvalue_count; i++)
    {
        Upvalue *upvalue = &self.upvalues[i];
        if (upvalue.index == index && upvalue.is_local == is_local)
        {
            return i;
        }
    }

    if (upvalue_count == MAX_UPVALUES)
    {
        self.parser.error("Too many closure variables in function");
        return 0;
    }

    self.upvalues[upvalue_count].is_local = is_local;
    self.upvalues[upvalue_count].index = index;
    return self.function.upvalue_count++;
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
                self.parser.error("Cannot read a local variable within its own initializer");
            }

            return i;
        }
    }

    return -1;
}

fn int Compiler.resolve_upvalue(&self, Token *name)
{
    if (self.parent == null) return -1;

    int local = self.parent.resolve_local(name);
    if (local != -1)
    {
        self.parent.locals[local].is_captured = true;
        return self.add_upvalue(ibyte(local), true);
    }

    int upvalue = self.parent.resolve_upvalue(name);
    if (upvalue != -1)
    {
        return self.add_upvalue(ibyte(upvalue), false);
    }

    return -1;
}

fn void Compiler.named_variable(&self, Token name, bool can_assign)
{
    OpCode get_op, set_op;
    int arg = self.resolve_local(&name);

    if (arg != -1)
    {
        get_op = GET_LOCAL;
        set_op = SET_LOCAL;
    }
    else if ((arg = self.resolve_upvalue(&name)) != -1)
    {
        get_op = GET_UPVALUE;
        set_op = SET_UPVALUE;
    }
    else
    {
        arg = self.identifier_constant(&name);
        get_op = GET_GLOBAL;
        set_op = SET_GLOBAL;
    }

    if (self.parser.match(EQUAL) && can_assign)
    {
        self.expression();
        self.emit_op_byte(set_op, arg);
    }
    else
    {
        self.emit_op_byte(get_op, arg);
    }
}

fn int Compiler.parse_variable(&self, String message)
{
    self.parser.consume(IDENTIFIER, message);

    self.declare_variable();
    if (self.scope_depth > 0) return 0;

    return self.identifier_constant(&self.parser.previous);
}

fn void Compiler.declare_variable(&self)
{
    if (self.scope_depth == 0) return;

    Token *name = &self.parser.previous;
    for (int i = self.local_count - 1; i >= 0; i--)
    {
        Local *local = &self.locals[i];
        if (local.depth != -1 && local.depth < self.scope_depth)
        {
            break;
        }

        if (identifiers_equal(name, &local.name))
        {
            self.parser.error("Already a variable with this name in this scope");
        }
    }

    self.add_local(*name);
}

fn void Compiler.mark_initialized(&self)
{
    if (self.scope_depth == 0) return;
    self.locals[self.local_count - 1].depth = self.scope_depth;
}

fn void Compiler.define_variable(&self, int global)
{
    if (self.scope_depth > 0)
    {
        self.mark_initialized();
        return;
    }

    self.emit_op_byte(DEFINE_GLOBAL, global);
}

fn char Compiler.argument_list(&self)
{
    char argc = 0;
    if (!self.parser.check(RPAREN))
    {
        do
        {
            if (argc == 255)
            {
                self.parser.error("Cannot have more than 255 arguments to a call");
            }

            self.expression();
            argc++;
        } while (self.parser.match(COMMA));
    }

    self.parser.consume(RPAREN, "Expected ')' after arguments");
    return argc;
}

fn void Compiler.class_declaration(&self)
{
    self.parser.consume(IDENTIFIER, "Expected class name");
    Token class_name = self.parser.previous;

    int name_constant = self.identifier_constant(&class_name);
    self.declare_variable();

    self.emit_op_byte(CLASS, name_constant);
    self.define_variable(name_constant);

    ClassCompiler class_compiler;
    class_compiler.enclosing = current_class;
    class_compiler.has_superclass = false;
    current_class = &class_compiler;

    if (self.parser.match(LT))
    {
        self.parser.consume(IDENTIFIER, "Expected superclass name");
        variable(self, false);

        if (identifiers_equal(&class_name, &self.parser.previous))
        {
            self.parser.error("A class cannot inherit from itself");
        }

        self.begin_scope();
        self.add_local(synthetic_token("super"));
        self.define_variable(0);

        self.named_variable(class_name, false);
        self.emit_op(INHERIT);
        class_compiler.has_superclass = true;
    }

    self.named_variable(class_name, false);
    self.parser.consume(LBRACE, "Expected '{' before class body");

    while (!self.parser.check(RBRACE) && !self.parser.check(EOF))
    {
        self.method();
    }

    self.parser.consume(RBRACE, "Expected '{' after class body");
    self.emit_op(POP);

    if (class_compiler.has_superclass)
    {
        self.end_scope();
    }

    current_class = current_class.enclosing;
}

fn void Compiler.fun_declaration(&self)
{
    int global = self.parse_variable("Expected function name");
    self.mark_initialized();
    self.fun_statement(FUNCTION);
    self.define_variable(global);
}

fn void Compiler.var_declaration(&self)
{
    int global = self.parse_variable("Expected variable name");

    if (self.parser.match(EQUAL))
    {
        self.expression();
    }
    else
    {
        self.emit_op(NIL);
    }

    self.parser.consume(SEMICOLON, "Expected ';' after variable declaration");
    self.define_variable(global);
}

fn void Compiler.declaration(&self)
{
    switch
    {
        case self.parser.match(CLASS):
            self.class_declaration();
        case self.parser.match(FUN):
            self.fun_declaration();
        case self.parser.match(VAR):
            self.var_declaration();
        default:
            self.statement();
    }

    if (self.parser.panic_mode) self.parser.synchronize();
}

fn ParseRule *get_rule(TokenType type)
{
    return &rules[type.ordinal];
}

fn bool identifiers_equal(Token *a, Token *b)
{
    if (a.length != b.length) return false;
    return mem::equals(&a.lexeme[0], &b.lexeme[0], a.length);
}

fn void dot(Compiler *self, bool can_assign)
{
    self.parser.consume(IDENTIFIER, "Expected property name after '.'");
    int name = self.identifier_constant(&self.parser.previous);

    if (can_assign && self.parser.match(EQUAL))
    {
        self.expression();
        self.emit_op_byte(SET_PROPERTY, name);
    }
    else if (self.parser.match(LPAREN))
    {
        char argc = self.argument_list();
        self.emit_op_byte(INVOKE, name);
        self.emit_byte(argc);
    }
    else
    {
        self.emit_op_byte(GET_PROPERTY, name);
    }
}

fn void call(Compiler *self, bool can_assign)
{
    char argc = self.argument_list();
    self.emit_op_byte(CALL, argc);
}

fn void and_(Compiler *self, bool can_assign)
{
    int end_jump = self.emit_jump(JUMP_IF);

    self.emit_op(POP);
    self.parse_precedence(AND);

    self.patch_jump(end_jump);
}

fn void or_(Compiler *self, bool can_assign)
{
    int else_jump = self.emit_jump(JUMP_IF);
    int end_jump = self.emit_jump(JUMP);

    self.patch_jump(else_jump);
    self.emit_op(POP);

    self.parse_precedence(OR);
    self.patch_jump(end_jump);
}

fn void binary(Compiler *self, bool can_assign)
{
    TokenType op_type = self.parser.previous.type;
    ParseRule *rule = get_rule(op_type);
    self.parse_precedence(rule.precedence + 1);

    switch (op_type)
    {
        case EQEQ:      self.emit_op(EQUAL);
        case NOTEQ:     self.emit_ops(EQUAL, NOT);
        case GT:        self.emit_op(GREATER);
        case GTEQ:      self.emit_ops(LESS, NOT);
        case LT:        self.emit_op(LESS);
        case LTEQ:      self.emit_ops(GREATER, NOT);
        case MINUS:     self.emit_op(SUBTRACT);
        case PLUS:      self.emit_op(ADD);
        case SLASH:     self.emit_op(DIVIDE);
        case STAR:      self.emit_op(MULTIPLY);
        default:        return; // Unreachable
    }
}

fn void unary(Compiler *self, bool can_assign)
{
    TokenType op_type = self.parser.previous.type;
    self.parse_precedence(UNARY);

    switch (op_type)
    {
        case NOT:   self.emit_op(NOT);
        case MINUS: self.emit_op(NEGATE);
        default:    return; // Unreachable
    }
}

fn void grouping(Compiler *self, bool can_assign)
{
    self.expression();
    self.parser.consume(RPAREN, "Expected ')' after expression");
}

fn void number(Compiler *self, bool can_assign)
{
    double value = self.parser.previous.lexeme.to_double()!!;
    self.emit_constant(make_num(value));
}

fn void literal(Compiler *self, bool can_assign)
{
    switch (self.parser.previous.type)
    {
        case FALSE: self.emit_op(FALSE);
        case NIL:   self.emit_op(NIL);
        case TRUE:  self.emit_op(TRUE);
        default:    return; // Unreachable
    }
}

fn void string(Compiler *self, bool can_assign)
{
    self.emit_constant(
        make_obj(value::copy_string(
            self.parser.vm,
            &self.parser.previous.lexeme[1],
            self.parser.previous.length - 2
        ))
    );
}

fn void variable(Compiler *self, bool can_assign)
{
    self.named_variable(self.parser.previous, can_assign);
}

fn void this(Compiler *self, bool can_assign)
{
    if (current_class == null)
    {
        self.parser.error("Cannot use 'this' outside of a class");
        return;
    }

    variable(self, false);
}

fn void super(Compiler *self, bool can_assign)
{
    if (current_class == null)
    {
        self.parser.error("Cannot use 'super' outside of a class");
    }
    else if (!current_class.has_superclass)
    {
        self.parser.error("Cannot use 'super' in a class with no superclass");
    }

    self.parser.consume(DOT, "Expected '.' after 'super'");
    self.parser.consume(IDENTIFIER, "Expected superclass method name");
    int name = self.identifier_constant(&self.parser.previous);

    self.named_variable(synthetic_token("this"), false);
    if (self.parser.match(LPAREN))
    {
        char argc = self.argument_list();
        self.named_variable(synthetic_token("super"), false);
        self.emit_op_byte(SUPER_INVOKE, name);
        self.emit_byte(argc);
    }
    else
    {
        self.named_variable(synthetic_token("super"), false);
        self.emit_op_byte(GET_SUPER, name);
    }
}

fn Token synthetic_token(String text)
{
    Token token;
    token.lexeme = text;
    token.length = text.len;
    return token;
}

fn ObjFn *compile(LoxVM *vm, char *source) @public
{
    Lexer lexer;
    lexer.init(source);

    Parser parser;
    parser.init(vm, &lexer);

    Compiler self;
    self.init(&parser, null, SCRIPT);

    self.parser.advance();
    while (!self.parser.match(EOF)) self.declaration();

    ObjFn *function = self.end();
    return self.parser.had_error ? null : function;
}
