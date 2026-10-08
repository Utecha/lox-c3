module lox::compiler @private;
import lox::debug;
import lox::lexer;
import lox::opcode;
import lox::token;
import lox::value;
import std::io @norecurse;

//------------------------------------------------------------------------------

<* A type alias for a pointer to a function for parsing an expression.  *>
alias ParseFn = fn void (Compiler *cc, bool assignable);

<* The defined levels of precedence that are followed for parsing exprssions. *>
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

<*
    A rule for parsing an expression.

    Each rule maintains the order of precedence and pointers to the appropriate
    functions for the type of expression.
*>
struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

<* Maintains the necessary data for parsing the Lox language. *>
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

<*
    Maintains the necessary data for compiling the Lox language into bytecode.

    A compiler is specific to the function that it is compiling. Since a script
    itself is an implicit function, the top level (first) compiler is technically
    non-specific. It maintains the global code and is otherwise just the parent
    of the next subsequent compiler.
*>
struct Compiler
{
    Parser *parser;
    Compiler *parent;
    ObjFun *fun;
    sz num_slots;
}

//------------------------------------------------------------------------------

<* The maximum number of constants that can be defined in a single function. *>
const sz MAX_CONSTANTS  = 1 << 16; // 65536

<* The maximum amount of bytecode that can be jumped over. *>
const sz MAX_JUMP       = 1 << 16; // 65536

<* A table mapping specific tokens to their respective ParseRule's. *>
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

<*
    Compiles the given [source] into the appropriate bytecode.

    The top level compiler compiles the entire script as if it were an implicit
    "main" function. Each subsequent function will receive its own compiler,
    with the parent being either the top level compiler, or the compiler of the
    enclosing function.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] source : "A pointer to the beginning of the source code."
*>
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

<*
    Returns a pointer to the respective ParseRule for the given token [type].

    @param type : "The token type corresponding to the desired rule."
*>
fn ParseRule *get_rule(TokenType type) @local
{
    return &RULES[type];
}

<*
    Initializes the given parser with the given [vm] and [lexer], with the rest
    of its members being zero initialized.

    @param [&inout] p : "A pointer to a Parser."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] lexer : "A pointer to a LoxLexer."
*>
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

<*
    Initializes the given compiler with a [parent] compiler and a [parser].

    Afterwards, it is initialized with a pointer to a new function object
    to compile into and added to the stack of compilers held by the LoxVM.

    @param [&inout] cc : "A pointer to a Compiler."
    @param [inout] parent : "A pointer to a parent Compiler."
    @param [&inout] parser : "A pointer to a Parser."
*>
fn void init(Compiler *cc, Compiler *parent, Parser *parser) @local
{
    cc.parser = parser;
    cc.parent = parent;
    cc.fun = value::new_function(cc.parser.vm);

    /*
     * This is an enforced arbitrary minimum number of slots.
     *
     * The `num_slots` property is used to set the compiling function's
     * 'max_slots' property, which is itself used to determine how large of a
     * stack to allocate for the VM.
     *
     * The size will *always* be at least `fun.max_slots + 1`, meaning the
     * bare minimum size of the VM's stack is always 2 slots.
    */
    cc.num_slots = 1;
    cc.parser.vm.compiler = cc;
}

<*
    Reports that a compile time error has occurred at the given token.

    @param [&inout] p : "A pointer to a Parser."
    @param [&inout] t : "A pointer to the Token the error occurred at."
    @param fmt : "The format string for the error message."
    @param args : "The arguments for the format string."
*>
fn void error_at(Parser *p, Token *t, String fmt, args...) @local
{
    if (p.panic_mode) return;

    p.had_error = true;
    p.panic_mode = true;

    io::eprintf("{ ln %d } Error", t.line);
    switch (t.type)
    {
        case ERROR: io::eprintf(": "); // Lexical Error
        case EOF:   io::eprintf(" at EOF: ");
        default:    io::eprintf(" at '%s': ", t.lexeme);
    }

    io::eprintfn(fmt, ...args);
}

<*
    Reports that a compile time error has occurred at the previous token.

    @param [&inout] cc : "A pointer to a Compiler."
    @param fmt : "The format string for the error message."
    @param args : "The arguments for the format string."
*>
fn void ct_error(Compiler *cc, String fmt, args...) @inline @local
{
    error_at(cc.parser, &cc.parser.previous, fmt, ...args);
}

<*
    Reports that a compile time error has occurred at the current token.

    @param [&inout] cc : "A pointer to a Compiler."
    @param fmt : "The format string for the error message."
    @param args : "The arguments for the format string."
*>
fn void ct_error_current(Compiler *cc, String fmt, args...) @inline @local
{
    error_at(cc.parser, &cc.parser.current, fmt, ...args);
}

<*
    Reports that a compile time error will occur at the next token.

    @param [&inout] cc : "A pointer to a Compiler."
    @param fmt : "The format string for the error message."
    @param args : "The arguments for the format string."
*>
fn void ct_error_next(Compiler *cc, String fmt, args...) @inline @local
{
    error_at(cc.parser, &cc.parser.next, fmt, ...args);
}

<*
    Returns the type of the previous token.

    @param [&inout] cc : "A pointer to a Compiler."
*>
fn TokenType peek_prev(Compiler *cc) @inline @local
{
    return cc.parser.previous.type;
}

<*
    Returns the type of the current token.

    @param [&inout] cc : "A pointer to a Compiler."
*>
fn TokenType peek(Compiler *cc) @inline @local
{
    return cc.parser.current.type;
}

<*
    Returns the type of the next token.

    @param [&inout] cc : "A pointer to a Compiler."
*>
fn TokenType peek_next(Compiler *cc) @inline @local
{
    return cc.parser.next.type;
}

<*
    Sets up the token chain and loads the next token.

    @param [&inout] cc : "A pointer to a Compiler."
*>
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

<*
    If the current token matches the expected [type], the token is successfully
    consumed. Otherwise, an error is reported.

    @param [&inout] cc : "A pointer to a Compiler."
    @param type : "The type of token expected."
    @param message : "The error message used when the type does not match."
*>
fn void consume(Compiler *cc, TokenType type, String message) @local
{
    if (peek(cc) == type)
    {
        advance(cc);
        return;
    }

    ct_error_current(cc, message);
}

<*
    Returns whether the current token is of the expected [type].

    @param [&inout] cc : "A pointer to a Compiler."
    @param type : "The type of token expected."
*>
fn bool check(Compiler *cc, TokenType type) @local
{
    return peek(cc) == type;
}

<*
    Returns whether the current token is of the expected [type] and advancing
    to the next if it is.

    @param [&inout] cc : "A pointer to a Compiler."
    @param type : "The type of token expected."
*>
fn bool match(Compiler *cc, TokenType type) @local
{
    if (!check(cc, type)) return false;
    advance(cc);
    return true;
}

<*
    Attempts to add the given [value] to the compiling functions constants
    pool.

    If an error has occurred during compilation before this is called, the
    function is thrown out anyways so it is not added and '-1' is returned.

    If adding the constant is successful, the length of the pool is returned.

    If the maximum number of constants has been reached, the length is still
    returned, but a compile time error is reported to inform the user that
    they've reached that limit.

    @param [&inout] cc : "A pointer to a Compiler."
    @param value : "The Value to add to the constants pool."
*>
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

<*
    Emits a single byte argument and the corresponding line data to the
    compiling functions bytecode and line arrays, respectively, returning the
    length of the bytecode array.

    The line data is run-length encoded to save some memory.

    @param [&inout] cc : "A pointer to a Compiler."
    @param byte : "The byte to emit."
*>
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

<*
    Calls into `emit_byte` to emit a single bytecode instruction.

    Furthermore, this function tracks the high water mark for the VM's stack.
    It adds the "stack effect" of the given instruction to the compilers
    expected number of slots.

    If that number grows larger than the maximum slots expected by the function,
    it is reinitialized with the compilers expected number of slots.

    @param [&inout] cc : "A pointer to a Compiler."
    @param instruction : "The instruction to emit."
*>
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

<*
    Calls into `emit_opcode` to emit two successive bytecode instructions.

    @param [&inout] cc : "A pointer to a Compiler."
    @param code1 : "The first instruction to emit."
    @param code2 : "The second instruction to emit."
*>
fn void emit_opcodes(Compiler *cc, OpCode code1, OpCode code2) @local
{
    emit_opcode(cc, code1);
    emit_opcode(cc, code2);
}

<*
    Splits up a single byte into two bytes to handle arguments that are larger
    in size than a single byte.

    Calls into `emit_byte` to emit the split bytes.

    @param [&inout] cc : "A pointer to a Compiler."
    @param arg : "The byte to split and emit."
*>
fn void emit_short(Compiler *cc, sz arg) @local
{
    emit_byte(cc, (arg >> 8) & 0xff);
    emit_byte(cc, arg & 0xff);
}

<*
    Calls into `emit_opcode` and `emit_byte` to emit a single bytecode
    instruction and a single byte argument, successively.

    @param [&inout] cc : "A pointer to a Compiler."
    @param arg : "The byte to emit."
*>
fn sz emit_opcode_byte(Compiler *cc, OpCode instruction, sz arg) @local
{
    emit_opcode(cc, instruction);
    return emit_byte(cc, arg);
}

<*
    Calls into `emit_opcode` and `emit_short` to emit a single bytecode
    instruction and a two byte argument, successively.

    @param [&inout] cc : "A pointer to a Compiler."
    @param arg : "The byte to split and emit."
*>
fn void emit_opcode_short(Compiler *cc, OpCode instruction, sz arg) @local
{
    emit_opcode(cc, instruction);
    emit_short(cc, arg);
}

<*
    Emits the given jump [instruction] and two placeholder bytes which are
    meant to be patched later.

    Returns the length of the bytecode array to keep track of the location of
    the jump instruction for patching.

    @param [&inout] cc : "A pointer to a Compiler."
    @param instruction : "The jump instruction to emit."
*>
fn sz emit_jump(Compiler *cc, OpCode instruction) @local @nodiscard
{
    emit_opcode(cc, instruction);
    emit_byte(cc, 0xff);
    return emit_byte(cc, 0xff) - 1;
}

<*
    Calculates the amount of bytecode that needs to be jumped over and patches
    the placeholder bytes for the jump instruction found at [offset] - 1.

    @param [&inout] cc : "A pointer to a Compiler."
    @param offset : "The index of the first placeholder byte."
*>
fn void patch_jump(Compiler *cc, sz offset) @local
{
    sz jump = cc.fun.code.len() - offset - 2;
    if (jump > MAX_JUMP) ct_error(cc, "Too much code to jump over.");

    cc.fun.code.data[offset] = (char)(jump >> 8) & 0xff;
    cc.fun.code.data[offset + 1] = (char)(jump) & 0xff;
}

<*
    Adds the given [value] to the compiling functions constants pool and emits
    the appropriate bytes to load the constant.

    @param [&inout] cc : "A pointer to a Compiler."
    @param value : "The value to emit."
*>
fn void emit_constant(Compiler *cc, Value value) @local
{
    sz constant = add_constant(cc, value);
    emit_opcode_short(cc, CONSTANT, constant);
}

<*
    Emits a return instruction.

    @param [&inout] cc : "A pointer to a Compiler."
*>
fn void emit_return(Compiler *cc) @local
{
    emit_opcode(cc, RETURN);
}

<*
    Finishes up the compilation of the current function.

    If compilation was successful, the return instruction is emitted, the
    compiler is popped off of the compiler stack, and the function object
    is returned.

    If a compile error occurs before this function is called, the compiler
    is simply popped off the compiler stack and 'null' is returned.

    @param [&inout] cc : "A pointer to a Compiler."
*>
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

<*
    The ParseFn for compiling a "group" expression.

    @param [&inout] cc : "A pointer to a Compiler."
    @param assignable : "Determines whether the expression is assignable."
*>
fn void grouping(Compiler *cc, bool assignable) @local
{
    expression(cc);
    consume(cc, RPAREN, "Expected ')' after expression");
}

<*
    The ParseFn for compiling literal expressions such as numbers, strings,
    and singletons such as 'nil'.

    @param [&inout] cc : "A pointer to a Compiler."
    @param assignable : "Determines whether the expression is assignable."
*>
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

<*
    The ParseFn for compiling a unary expression.

    @param [&inout] cc : "A pointer to a Compiler."
    @param assignable : "Determines whether the expression is assignable."
*>
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

<*
    The ParseFn for compiling a binary expression.

    @param [&inout] cc : "A pointer to a Compiler."
    @param assignable : "Determines whether the expression is assignable."
*>
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

<*
    The ParseFn for compiling a logical AND expression.

    @param [&inout] cc : "A pointer to a Compiler."
    @param assignable : "Determines whether the expression is assignable."
*>
fn void logical_and(Compiler *cc, bool assignable) @local
{
    sz jump = emit_jump(cc, AND);
    parse_precedence(cc, AND);
    patch_jump(cc, jump);
}

<*
    The ParseFn for compiling a logical OR expression.

    @param [&inout] cc : "A pointer to a Compiler."
    @param assignable : "Determines whether the expression is assignable."
*>
fn void logical_or(Compiler *cc, bool assignable) @local
{
    sz jump = emit_jump(cc, OR);
    parse_precedence(cc, OR);
    patch_jump(cc, jump);
}

<*
    The ParseFn for compiling a conditional (ternary) expression.

    @param [&inout] cc : "A pointer to a Compiler."
    @param assignable : "Determines whether the expression is assignable."
*>
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

<*
    Parses and compiles an expression based on the given [precedence].

    @param [&inout] cc : "A pointer to a Compiler."
    @param precedence : "The precedence of the expression."
*>
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

<*
    Compiles a single expression.

    @param [&inout] cc : "A pointer to a Compiler."
*>
fn void expression(Compiler *cc) @local
{
    parse_precedence(cc, ASSIGNMENT);
}
