module lox::compiler @private;
import lox::debug;
import lox::lexer;
import lox::opcode;
import lox::token;
import lox::value;
import std::io @norecurse;

//------------------------------------------------------------------------------

alias ParseFn = fn void (Compiler *cc, bool assignable);

enum Precedence : int
{
    NONE,
    ASSIGNMENT,
    CONDITIONAL,
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

struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

struct Parser
{
    LoxVM *vm;
    LoxLexer *lexer;
    Token next;
    Token current;
    Token previous;
    bool had_error;
    bool panic_mode;
}

struct Compiler
{
    Parser *parser;
    Compiler *parent;
    ObjFun *fun;
    sz num_slots;
}

//------------------------------------------------------------------------------

const sz MAX_CONSTANTS  = 1 << 16; // 65536
const sz MAX_JUMP       = 1 << 16; // 65536

const ParseRule[] RULES = {
    [TokenType.LPAREN]      = { &grouping,      null,           NONE },
    [TokenType.RPAREN]      = { null,           null,           NONE },
    [TokenType.LBRACE]      = { null,           null,           NONE },
    [TokenType.RBRACE]      = { null,           null,           NONE },
    [TokenType.LBRACK]      = { null,           null,           NONE },
    [TokenType.RBRACK]      = { null,           null,           NONE },
    [TokenType.COMMA]       = { null,           null,           NONE },
    [TokenType.DOT]         = { null,           null,           NONE },
    [TokenType.COLON]       = { null,           null,           NONE },
    [TokenType.QUESTION]    = { null,           &conditional,   ASSIGNMENT },
    [TokenType.SEMICOLON]   = { null,           null,           NONE },
    [TokenType.EQUAL]       = { null,           null,           NONE },
    [TokenType.ISEQ]        = { null,           &binary,        EQUALITY },
    [TokenType.NOTEQ]       = { null,           &binary,        EQUALITY },
    [TokenType.GT]          = { null,           &binary,        COMPARISON },
    [TokenType.GTEQ]        = { null,           &binary,        COMPARISON },
    [TokenType.LT]          = { null,           &binary,        COMPARISON },
    [TokenType.LTEQ]        = { null,           &binary,        COMPARISON },
    [TokenType.MINUS]       = { &unary,         &binary,        TERM },
    [TokenType.PLUS]        = { null,           &binary,        TERM },
    [TokenType.PERCENT]     = { null,           &binary,        FACTOR },
    [TokenType.SLASH]       = { null,           &binary,        FACTOR },
    [TokenType.STAR]        = { null,           &binary,        FACTOR },
    [TokenType.IDENTIFIER]  = { null,           null,           NONE },
    [TokenType.NUMBER]      = { &literal,       null,           NONE },
    [TokenType.STRING]      = { &literal,       null,           NONE },
    [TokenType.AND]         = { null,           &logical_and,   AND },
    [TokenType.BREAK]       = { null,           null,           NONE },
    [TokenType.CLASS]       = { null,           null,           NONE },
    [TokenType.CONST]       = { null,           null,           NONE },
    [TokenType.CONTINUE]    = { null,           null,           NONE },
    [TokenType.ELSE]        = { null,           null,           NONE },
    [TokenType.FALSE]       = { &literal,       null,           NONE },
    [TokenType.FOR]         = { null,           null,           NONE },
    [TokenType.FUN]         = { null,           null,           NONE },
    [TokenType.IF]          = { null,           null,           NONE },
    [TokenType.NIL]         = { &literal,       null,           NONE },
    [TokenType.NOT]         = { &unary,         null,           NONE },
    [TokenType.OR]          = { null,           &logical_or,    OR },
    [TokenType.PRINT]       = { null,           null,           NONE },
    [TokenType.RETURN]      = { null,           null,           NONE },
    [TokenType.SUPER]       = { null,           null,           NONE },
    [TokenType.THIS]        = { null,           null,           NONE },
    [TokenType.TRUE]        = { &literal,       null,           NONE },
    [TokenType.VAR]         = { null,           null,           NONE },
    [TokenType.WHILE]       = { null,           null,           NONE },
    [TokenType.ERROR]       = { null,           null,           NONE },
    [TokenType.EOF]         = { null,           null,           NONE },
};

//------------------------------------------------------------------------------

fn ObjFun *compile(LoxVM *vm, char *source)
{
    LoxLexer l;
    lexer::init(&l, source);

    $if $feat(DEBUG) &&& debug::DUMP_TOKENS:
        debug::dump_tokens(&l);
        lexer::init(&l, source); // Reset for reuse.
    $endif

    Parser p;
    init_parser(&p, vm, &l);

    Compiler cc;
    init(&cc, null, &p);

    advance(&cc); // Load next -> current
    advance(&cc); // Load current -> previous

    expression(&cc);
    consume(&cc, EOF, "Expected end of expression");

    return end_compile(&cc);
}

//------------------------------------------------------------------------------

fn ParseRule *get_rule(TokenType type) @local
{
    return &RULES[type];
}

fn void init_parser(Parser *p, LoxVM *vm, LoxLexer *lexer) @local
{
    p.vm = vm;
    p.lexer = lexer;
    p.next.type = EOF;
    p.next.lexeme = "";
    p.next.length = 0;
    p.next.line = 0;
    p.had_error = false;
    p.panic_mode = false;
}

fn void init(Compiler *cc, Compiler *parent, Parser *parser) @local
{
    cc.parser = parser;
    cc.parent = parent;
    cc.fun = value::new_function(cc.parser.vm);

    // This is an enforced arbitrary minimum number of slots. When the VM's
    // stack is allocated, the size will always be `cc.fun.max_slots + 1`,
    // meaning there is a guarantee of at least 2 slots being available.
    cc.num_slots = 1;
    cc.parser.vm.compiler = cc;
}

fn void error_at(Parser *p, Token *t, String fmt, args...) @local
{
    if (p.panic_mode) return;

    p.had_error = true;
    p.panic_mode = true;

    io::eprintf("[ Compile ] { ln %d } Error", t.line);
    switch (t.type)
    {
        case ERROR: break; // Lexical Error
        case EOF:   io::eprintf(" at EOF: ");
        default:    io::eprintf(" at '%s': ", t.lexeme);
    }

    io::eprintfn(fmt, ...args);
}

fn void ct_error(Compiler *cc, String fmt, args...) @inline @local
{
    error_at(cc.parser, &cc.parser.previous, fmt, ...args);
}

fn void ct_error_current(Compiler *cc, String fmt, args...) @inline @local
{
    error_at(cc.parser, &cc.parser.current, fmt, ...args);
}

fn void ct_error_next(Compiler *cc, String fmt, args...) @inline @local
{
    error_at(cc.parser, &cc.parser.next, fmt, ...args);
}

fn TokenType peek_prev(Compiler *cc) @inline @local
{
    return cc.parser.previous.type;
}

fn TokenType peek(Compiler *cc) @inline @local
{
    return cc.parser.current.type;
}

fn TokenType peek_next(Compiler *cc) @inline @local
{
    return cc.parser.next.type;
}

fn void advance(Compiler *cc) @local
{
    cc.parser.previous = cc.parser.current;
    cc.parser.current = cc.parser.next;

    for (;;)
    {
        cc.parser.next = lexer::next(cc.parser.lexer);
        if (peek_next(cc) != ERROR) break;

        ct_error_next(cc, cc.parser.next.lexeme);
    }
}

fn void consume(Compiler *cc, TokenType type, String message) @local
{
    if (peek(cc) == type)
    {
        advance(cc);
        return;
    }

    ct_error_current(cc, message);
}

fn bool check(Compiler *cc, TokenType type) @local
{
    return peek(cc) == type;
}

fn bool match(Compiler *cc, TokenType type) @local
{
    if (!check(cc, type)) return false;
    advance(cc);
    return true;
}

fn sz add_constant(Compiler *cc, Value value) @local
{
    if (cc.parser.had_error) return -1;

    if (cc.fun.constants.len() < MAX_CONSTANTS)
    {
        cc.fun.constants.append(cc.parser.vm, value);
    }
    else
    {
        ct_error(
            cc,
            "A function many only contain %d unique constants.",
            MAX_CONSTANTS
        );
    }

    return cc.fun.constants.len() - 1;
}

fn sz emit_byte(Compiler *cc, sz byte) @local
{
    if (cc.fun.code.len() == 0 ||
        cc.fun.lines[cc.fun.lines.len() - 1].n != cc.parser.previous.line)
    {
        cc.fun.lines.append(
            cc.parser.vm,
            (Line) { .n = cc.parser.previous.line, .offset = cc.fun.code.len() }
        );
    }

    cc.fun.code.append(cc.parser.vm, (char)byte);
    return cc.fun.code.len() - 1;
}

fn void emit_opcode(Compiler *cc, OpCode instruction) @local
{
    emit_byte(cc, instruction.ordinal);

    // Keep track of the stacks high water mark.
    cc.num_slots += instruction.stack_effect;
    if (cc.num_slots > cc.fun.max_slots)
    {
        cc.fun.max_slots = cc.num_slots;
    }
}

fn void emit_opcodes(Compiler *cc, OpCode code1, OpCode code2) @local
{
    emit_opcode(cc, code1);
    emit_opcode(cc, code2);
}

fn void emit_short(Compiler *cc, sz arg) @local
{
    emit_byte(cc, (arg >> 8) & 0xff);
    emit_byte(cc, arg & 0xff);
}

fn sz emit_opcode_byte(Compiler *cc, OpCode instruction, sz arg) @local
{
    emit_opcode(cc, instruction);
    return emit_byte(cc, arg);
}

fn void emit_opcode_short(Compiler *cc, OpCode instruction, sz arg) @local
{
    emit_opcode(cc, instruction);
    emit_short(cc, arg);
}

fn sz emit_jump(Compiler *cc, OpCode instruction) @local
{
    emit_opcode(cc, instruction);
    emit_byte(cc, 0xff);
    return emit_byte(cc, 0xff) - 1;
}

fn void patch_jump(Compiler *cc, sz offset) @local
{
    sz jump = cc.fun.code.len() - offset - 2;
    if (jump > MAX_JUMP) ct_error(cc, "Too much code to jump over.");

    cc.fun.code.data[offset] = (char)(jump >> 8) & 0xff;
    cc.fun.code.data[offset + 1] = (char)(jump) & 0xff;
}

fn void emit_constant(Compiler *cc, Value value) @local
{
    sz constant = add_constant(cc, value);
    emit_opcode_short(cc, CONSTANT, constant);
}

fn void emit_return(Compiler *cc) @local
{
    emit_opcode(cc, RETURN);
}

fn ObjFun *end_compile(Compiler *cc) @local
{
    // If we hit an error, don't bother finishing the function.
    if (cc.parser.had_error)
    {
        cc.parser.vm.compiler = cc.parent;
        return null;
    }

    emit_return(cc);

    // Pop the current compiler off the stack.
    cc.parser.vm.compiler = cc.parent;

    $if $feat(DEBUG) &&& debug::DUMP_CODE:
        debug::disassemble(cc.fun, "Script");
    $endif

    return cc.fun;
}

fn void grouping(Compiler *cc, bool assignable) @local
{
    expression(cc);
    consume(cc, RPAREN, "Expected ')' after expression");
}

fn void literal(Compiler *cc, bool assignable) @local
{
    switch (peek_prev(cc))
    {
        case NUMBER:
            double? value = cc.parser.previous.lexeme.to_double();
            if (catch value)
                { ct_error(cc, "Invalid numeric literal."); }
            else
                { emit_constant(cc, value::make_num(value)); }

        case STRING:
            break; // Not yet implemented

        case NIL:
            emit_opcode(cc, NIL);

        case FALSE:
            emit_opcode(cc, FALSE);

        case TRUE:
            emit_opcode(cc, TRUE);

        default:
            unreachable();
    }
}

fn void unary(Compiler *cc, bool assignable) @local
{
    TokenType operator = peek_prev(cc);
    parse_precedence(cc, UNARY);

    switch (operator)
    {
        case MINUS: emit_opcode(cc, NEGATE);
        case NOT:   emit_opcode(cc, NOT);
        default:    unreachable();
    }
}

fn void binary(Compiler *cc, bool assignable) @local
{
    TokenType operator = peek_prev(cc);
    ParseRule *rule = get_rule(operator);
    parse_precedence(cc, (Precedence)(rule.precedence.ordinal + 1));

    switch (operator)
    {
        case MINUS:     emit_opcode(cc, SUB);
        case PLUS:      emit_opcode(cc, ADD);
        case PERCENT:   emit_opcode(cc, MOD);
        case SLASH:     emit_opcode(cc, DIV);
        case STAR:      emit_opcode(cc, MUL);
        case ISEQ:      emit_opcode(cc, EQUAL);
        case NOTEQ:     emit_opcodes(cc, EQUAL, NOT);
        case GT:        emit_opcode(cc, GREATER);
        case GTEQ:      emit_opcodes(cc, LESS, NOT);
        case LT:        emit_opcode(cc, LESS);
        case LTEQ:      emit_opcodes(cc, GREATER, NOT);
        default:        unreachable();
    }
}

fn void logical_and(Compiler *cc, bool assignable) @local
{
    sz jump = emit_jump(cc, AND);
    parse_precedence(cc, AND);
    patch_jump(cc, jump);
}

fn void logical_or(Compiler *cc, bool assignable) @local
{
    sz jump = emit_jump(cc, OR);
    parse_precedence(cc, OR);
    patch_jump(cc, jump);
}

fn void conditional(Compiler *cc, bool assignable) @local
{
    // Jump to the else branch if the condition is false.
    sz if_jump = emit_jump(cc, JUMP_IF);

    // Compile the `then` branch.
    parse_precedence(cc, CONDITIONAL);
    consume(cc, COLON, "Expected ':' after conditional `then` branch.");

    // Jump over the else branch when the if branch is taken.
    sz else_jump = emit_jump(cc, JUMP);

    // Compile the else branch.
    patch_jump(cc, if_jump);
    parse_precedence(cc, ASSIGNMENT);

    // Patch the jump over the else.
    patch_jump(cc, else_jump);
}

fn void parse_precedence(Compiler *cc, Precedence precedence) @local
{
    advance(cc);

    ParseFn prefix_rule = get_rule(peek_prev(cc)).prefix;
    if (!prefix_rule)
    {
        ct_error(cc, "Expected expression");
        return;
    }

    bool assignable = precedence <= ASSIGNMENT;
    prefix_rule(cc, assignable);

    while (precedence <= get_rule(peek(cc)).precedence)
    {
        advance(cc);

        ParseFn infix_rule = get_rule(peek_prev(cc)).infix;
        infix_rule(cc, assignable);
    }
}

fn void expression(Compiler *cc) @local
{
    parse_precedence(cc, ASSIGNMENT);
}
