module lox::compiler;
import lox::chunk;
import lox::common;
import lox::error;
import lox::lexer;
import lox::memory;
import lox::object;
import lox::value;

//===----------------===//
//       Parser
//===----------------===//

<*
    The structure representing a (Parser) object.
*>
struct Parser
{
    Token current;
    Token previous;
    bool had_error;
    bool panic_mode;
}

<*
    An enumerator of operator precedence, used to Pratt-Parse tokens.
*>
enum Precedence : int
{
    NONE,
    ASSIGNMENT,
    TERNARY,
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

<* Function pointer for a ParseFn *>
def ParseFn = fn void (bool can_assign);

<*
    The structure representing the rules in which the (Parser) follows, used for the
    Pratt-Parsing technique.
*>
struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

<* Global (Parser) object *>
Parser parser @builtin;

<*
    The (ParseRule)'s defined for the Lox language.
*>
ParseRule[*] rules = {
    [TokenType.ERROR]       = { null,       null,       Precedence.NONE },
    [TokenType.EOF]         = { null,       null,       Precedence.NONE },
    [TokenType.LPAREN]      = { &grouping,  &call,      Precedence.CALL },
    [TokenType.RPAREN]      = { null,       null,       Precedence.NONE },
    [TokenType.LBRACE]      = { null,       null,       Precedence.NONE },
    [TokenType.RBRACE]      = { null,       null,       Precedence.NONE },
    [TokenType.COMMA]       = { null,       null,       Precedence.NONE },
    [TokenType.DOT]         = { null,       null,       Precedence.NONE },
    [TokenType.SEMICOLON]   = { null,       null,       Precedence.NONE },
    [TokenType.COLON]       = { null,       null,       Precedence.NONE },
    [TokenType.QMARK]       = { null,       &ternary,   Precedence.TERNARY },
    [TokenType.NOT]         = { &unary,     null,       Precedence.NONE },
    [TokenType.MODULUS]     = { null,       &binary,    Precedence.FACTOR },
    [TokenType.SLASH]       = { null,       &binary,    Precedence.FACTOR },
    [TokenType.STAR]        = { null,       &binary,    Precedence.FACTOR },
    [TokenType.MINUS]       = { &unary,     &binary,    Precedence.TERM },
    [TokenType.PLUS]        = { null,       &binary,    Precedence.TERM },
    [TokenType.ISEQ]        = { null,       &binary,    Precedence.EQUALITY },
    [TokenType.NOTEQ]       = { null,       &binary,    Precedence.EQUALITY },
    [TokenType.GT]          = { null,       &binary,    Precedence.COMPARISON },
    [TokenType.GTEQ]        = { null,       &binary,    Precedence.COMPARISON },
    [TokenType.LT]          = { null,       &binary,    Precedence.COMPARISON },
    [TokenType.LTEQ]        = { null,       &binary,    Precedence.COMPARISON },
    [TokenType.EQUAL]       = { null,       null,       Precedence.NONE },
    [TokenType.IDENTIFIER]  = { &variable,  null,       Precedence.NONE },
    [TokenType.NUMBER]      = { &number,    null,       Precedence.NONE },
    [TokenType.STRING]      = { &string,    null,       Precedence.NONE },
    [TokenType.AND]         = { null,       &and,       Precedence.AND },
    [TokenType.CLASS]       = { null,       null,       Precedence.NONE },
    [TokenType.ELSE]        = { null,       null,       Precedence.NONE },
    [TokenType.FALSE]       = { &literal,   null,       Precedence.NONE },
    [TokenType.FOR]         = { null,       null,       Precedence.NONE },
    [TokenType.FUN]         = { null,       null,       Precedence.NONE },
    [TokenType.IF]          = { null,       null,       Precedence.NONE },
    [TokenType.NIL]         = { &literal,   null,       Precedence.NONE },
    [TokenType.OR]          = { null,       &or,        Precedence.OR },
    [TokenType.PRINT]       = { null,       null,       Precedence.NONE },
    [TokenType.RETURN]      = { null,       null,       Precedence.NONE },
    [TokenType.SUPER]       = { null,       null,       Precedence.NONE },
    [TokenType.THIS]        = { null,       null,       Precedence.NONE },
    [TokenType.TRUE]        = { &literal,   null,       Precedence.NONE },
    [TokenType.VAR]         = { null,       null,       Precedence.NONE },
    [TokenType.WHILE]       = { null,       null,       Precedence.NONE },
};

<*
    Initializes the token fields for the [parser], then loads them up with the next token.

    If the (TokenType) is 'ERROR', it reports the error which sets the [had_error] and
    [panic_mode] fields to 'true', causing the parser to enter synchronization.

    This function is where all lexical errors are reported.

    Any other time error functions are called, they are parsing/compiling stage
    errors.
*>
fn void advance() @private
{
    parser.previous = parser.current;

    for (;;)
    {
        parser.current = lexer::get_next_token();
        if (parser.current.type != TokenType.ERROR) break;

        /*
         * This line is where all lexical errors are reported.
         *
         * Any other time error functions are called, they are parsing/compiling stage
         * errors.
        */
        error::@current(parser.current.lexeme);
    }
}

<*
    Matches the [current] tokens type with the given [type], then advances to the next if the result is 'true'.

    The difference between this function and 'match()', is that it is an error if the result of the comparison
    is 'false'. This function is used in place of match to enforce syntax errors.

    @param type "The expected TokenType"
    @param message "Error message used in the event the current Token does not match the given TokenType"
*>
fn void consume(TokenType type, String message) @private
{
    if (parser.current.type == type)
    {
        advance();
        return;
    }

    error::@current(message);
}

<*
    Returns 'true' if the current (Token) matches the given [type]. Otherwise, it returns
    false.

    @param type "The expected TokenType"
*>
fn bool check(TokenType type) @private
{
    return parser.current.type == type;
}

<*
    Similar to consume, except this does not produce an error if the (Token) does not
    match the given [type]. Return's 'true' if the (Token) DOES match.

    @param type "The expected TokenType"
*>
fn bool match(TokenType type) @private
{
    if (!check(type)) return false;

    advance();
    return true;
}

//===----------------===//
//      Compiler
//===----------------===//

<*
    Structure representing a 'Local' variable. This stores the token containing the
    name, as well as the depth of scope.
*>
struct Local
{
    Token name;
    int depth;
    bool is_captured;
}

<*
    Structure representing an 'Upvalue'. This is a local from a surrounding closure
    that is captured and hoisted onto the heap. At the point where a local that
    qualifies as an upvalue is used, the local will no longer be on the stack. This
    allows them to still be referenced deep within nested closures.
*>
struct Upvalue
{
    bool is_local;
    int index;
}

<*
    Enumerator of function types.

    CLOSURE     | A top-level function enclosing over another inner function.
    FUNCTION    | A regular top-level function.
    METHOD      | A function defined as a member of a class or object.
    SCRIPT      | The implicit 'main' function. *ALL* functions lie within this function.
*>
enum FunctionType : int
{
    FUNCTION,
    SCRIPT
}

<*
    Structure representing a 'Compiler'. This stores the state of parsing, such as the
    scope depth, as well as all of the local variables encountered.

    It also holds on to the current function being compiled. Each function owns its own
    (Chunk) to be compiled. As a result, each function gets its own compiler.

    This replaces the original global chunk, as now the global scope is treated as an
    implicit 'main' function. This is roughly how it works for most scripting languages
    which is why you're able to write things like 'if' statements and loops at the top level.
*>
struct Compiler
{
    Compiler *enclosing;

    ObjFunction *function;
    FunctionType type;

    Local[UINT8_COUNT] locals;
    int local_count;
    Upvalue[UINT8_COUNT] upvalues;
    int scope_depth;
}

<*
    Global variable used to signify the current compiler.

    Since each function gets its own compiler, and each compiler contains a pointer
    to its parent (it is a linked-list), this is used to tell the rest of this module
    which of those compilers is the 'current' one you should be compiling into.
*>
Compiler *current = null;

<*
    Initializes a new 'Compiler' structure.

    The compiler implicitly claims slot 0 of its stack of local variables for the
    VMs own internal use.

    @param [&inout] compiler "The compiler to initialize"
    @param type "The type of function to initialize the compiler for"
*>
fn void init(Compiler *compiler, FunctionType type)
{
    compiler.enclosing = current;
    compiler.function = null;
    compiler.type = type;
    compiler.local_count = 0;
    compiler.scope_depth = 0;
    compiler.function = object::new_function();
    current = compiler;

    if (type != FunctionType.SCRIPT)
    {
        current.function.name = object::copy_string(
            parser.previous.lexeme,
            parser.previous.lexeme.len
        );
    }

    Local *local = &current.locals[current.local_count++];
    local.name.lexeme = "";
    local.depth = 0;
    local.is_captured = false;
}

<*
    Return's the pointer to the current [compiling] chunk of bytecode.

    @ensure return != null
*>
fn Chunk *current_chunk() @private
{
    return &current.function.chunk;
}

<*
    Compiles a byte to the current [compiling] chunk of bytecode.

    @param byte "The OpCode (byte) to compile into the bytecode chunk"
*>
fn void emit_byte(char byte) @private
{
    current_chunk().write(byte, parser.previous.line);
}

<*
    Compiles 2 bytes to the current [compiling] chunk of bytecode.

    @param byte1 "The first byte to compile into the bytecode chunk"
    @param byte2 "The second byte to compile into the bytecode chunk"
*>
fn void emit_bytes(char byte1, char byte2) @private
{
    emit_byte(byte1);
    emit_byte(byte2);
}

<*
    Compiles the 3 bytes involved in a jump instruction to the current
    [compiling] chunk of bytecode.

    Unlike other emitter functions, this one returns the [instruction]
    offset in the bytecode array of the current chunk.

    The 2 bytes following the [instruction] are placeholder operands for
    the jump offset. This is later back-patched to store the correct
    offset, using the bytecode offset returned by this function.

    @param instruction "The instruction to emit"
*>
fn int emit_jump(char instruction)
{
    emit_byte(instruction);
    emit_byte(0xff);
    emit_byte(0xff);

    return current_chunk().count - 2;
}

<*
    Backpatches the jump offset for a jump instruction, based on the
    instruction [offset] provided.

    This is called *before* compiling the instruction that you want
    the jump to land on.

    @param offset "The instruction offset in the bytecode array"
*>
fn void patch_jump(int offset)
{
    int jump = current_chunk().count - offset - 2;
    if (jump > ushort.max)
    {
        error::@previous("Too much code to jump over");
    }

    current_chunk().code[offset] = to_byte((jump >> 8) & 0xff);
    current_chunk().code[offset + 1] = to_byte(jump & 0xff);
}

<*
    Compiles a loop instruction.

    This function takes in the [loop_start], which the offset
    of the instruction before the loop begins.
*>
fn void emit_loop(int loop_start) @private
{
    emit_byte(to_byte(OpCode.LOOP));

    int offset = current_chunk().count - loop_start + 2;
    if (offset > ushort.max)
    {
        error::@previous("Loop body is too large");
    }

    emit_byte(to_byte((offset >> 8) & 0xff));
    emit_byte(to_byte(offset & 0xff));
}

<*
    Add's the [value] to the current [compiling] chunks constants pool, returning
    the index to be loaded alongside the 'CONSTANT' instruction.

    @param value "The Value to add to the constants pool"
*>
fn char make_constant(Value value) @private
{
    int constant = current_chunk().add_constant(value);
    if (constant > char.max)
    {
        error::@previous("Too many constants in one chunk");
        return 0;
    }

    return (char)constant;
}

<*
    Compiles a constant [value], adding the constant to the chunks constants pool and
    writing the appropriate instructions to the current [compiling] chunk of bytecode.

    @param value "The Value to add to the chunks constants pool"
*>
fn void emit_constant(Value value) @private
{
    emit_bytes(to_byte(OpCode.CONSTANT), make_constant(value));
}

<*
    Compiles a 'RETURN' instruction into the current [compiling] chunk of bytecode.
*>
fn void emit_return() @private
{
    emit_byte(to_byte(OpCode.NIL));
    emit_byte(to_byte(OpCode.RETURN));
}

<*
    Ends compilation of the current function, returning the function fully compiled.

    This change result from the fact that functions own their own chunks, and a global
    chunk is no longer passed in to the compiler from the VM.

    At the top level, this returns the implicit 'main' function to the VM, which is the
    entirety of the compiled bytecode generated from the users source code.

    The VM then loads itself with the chunk provided by that function object and runs the
    interpreter on it.
*>
fn ObjFunction *end_compiler() @private
{
    emit_return();
    ObjFunction *function = current.function;

    $if $feature(DEBUG) &&& DUMP_CHUNK:
        if (!parser.had_error)
        {
            current_chunk().disassemble(
                function.name != null ?
                ((ZString)function.name.chars).str_view() : "<fn main>"
            );
        }
    $endif

    current = current.enclosing;
    return function;
}

<*
    Signifies the beginning of a new scope. The job of this is to increment
    the [scope_depth] stored by the current compiler.
*>
fn void begin_scope()
{
    current.scope_depth++;
}

<*
    Signifies an end to the current scope. The job of this is to decrement
    the [scope_depth] stored by the current compiler and clean up remaining
    locals when they go out of scope.
*>
fn void end_scope()
{
    current.scope_depth--;

    while (current.local_count > 0 &&
           current.locals[current.local_count - 1].depth > current.scope_depth)
    {
        if (current.locals[current.local_count - 1].is_captured)
            { emit_byte(to_byte(OpCode.CLOSE_UPVALUE)); }
        else
            { emit_byte(to_byte(OpCode.POP)); }

        current.local_count--;
    }
}

<*
    Compiles a conditional (also known as ternary) (?:) expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void ternary(bool can_assign) @private
{
    parse_precedence(Precedence.TERNARY);
    consume(TokenType.COLON, "Expected ':' between ternary 'true' and 'false' branches");
    parse_precedence(Precedence.TERNARY);
    emit_byte(to_byte(OpCode.TERNARY));
}

<*
    Compiles a binary expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void binary(bool can_assign) @private
{
    TokenType op_type = parser.previous.type;
    ParseRule *rule = get_rule(op_type);
    parse_precedence(rule.precedence + 1);

    switch (op_type)
    {
        case ISEQ:      emit_byte(to_byte(OpCode.EQUAL));
        case NOTEQ:     emit_bytes(to_byte(OpCode.EQUAL), to_byte(OpCode.NOT));
        case GT:        emit_byte(to_byte(OpCode.GREATER));
        case GTEQ:      emit_bytes(to_byte(OpCode.LESS), to_byte(OpCode.NOT));
        case LT:        emit_byte(to_byte(OpCode.LESS));
        case LTEQ:      emit_bytes(to_byte(OpCode.GREATER), to_byte(OpCode.NOT));
        case MINUS:     emit_byte(to_byte(OpCode.SUBTRACT));
        case PLUS:      emit_byte(to_byte(OpCode.ADD));
        case MODULUS:   emit_byte(to_byte(OpCode.MODULUS));
        case SLASH:     emit_byte(to_byte(OpCode.DIVIDE));
        case STAR:      emit_byte(to_byte(OpCode.MULTIPLY));
        default:        return; // Unreachable
    }
}

<*
    Compiles a call expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void call(bool can_assign) @private
{
    char arg_count = argument_list();
    emit_bytes(to_byte(OpCode.CALL), arg_count);
}

<*
    Compiles a literal expression, such as 'nil', 'true', or 'false'.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void literal(bool can_assign) @private
{
    switch (parser.previous.type)
    {
        case FALSE: emit_byte(to_byte(OpCode.FALSE));
        case NIL:   emit_byte(to_byte(OpCode.NIL));
        case TRUE:  emit_byte(to_byte(OpCode.TRUE));
        default:    return; // Unreachable
    }
}

<*
    Compiles a grouping '()' expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void grouping(bool can_assign) @private
{
    expression();
    consume(TokenType.RPAREN, "Expected ')' after expression");
}

<*
    Compiles a number literal.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void number(bool can_assign) @private
{
    double! value = parser.previous.lexeme.to_double();
    if (catch value) return;

    emit_constant(number_val(value));
}

<*
    Compiles a string literal.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void string(bool can_assign) @private
{
    emit_constant(
        obj_val(object::copy_string(
            parser.previous.lexeme[1..],
            parser.previous.lexeme.len - 2
        ))
    );
}

<*
    Compiles a unary (!, -) expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void unary(bool can_assign) @private
{
    TokenType op_type = parser.previous.type;

    parse_precedence(Precedence.UNARY);

    switch (op_type)
    {
        case MINUS: emit_byte(to_byte(OpCode.NEGATE));
        case NOT:   emit_byte(to_byte(OpCode.NOT));
        default:    return; // Unreachable
    }
}

<*
    Compiles a named variable.

    @param name "The name of the variable to compile"
    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void named_variable(Token name, bool can_assign) @private
{
    char get_op, set_op;
    int arg = resolve_local(current, &name);

    if (arg != -1)
    {
        get_op = to_byte(OpCode.GET_LOCAL);
        set_op = to_byte(OpCode.SET_LOCAL);
    }
    else if ((arg = resolve_upvalue(current, &name)) != -1)
    {
        get_op = to_byte(OpCode.GET_UPVALUE);
        set_op = to_byte(OpCode.SET_UPVALUE);
    }
    else
    {
        arg = identifier_constant(&name);
        get_op = to_byte(OpCode.GET_GLOBAL);
        set_op = to_byte(OpCode.SET_GLOBAL);
    }

    if (can_assign && match(TokenType.EQUAL))
    {
        expression();
        emit_bytes(set_op, (char)arg);
    }
    else
    {
        emit_bytes(get_op, (char)arg);
    }
}

<*
    Compiles a variable get expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void variable(bool can_assign) @private
{
    named_variable(parser.previous, can_assign);
}

<*
    Returns a pointer to the (ParseRule) associated with the given [type].

    @param type "The type to get the parse rule for"
*>
fn ParseRule *get_rule(TokenType type) @private
{
    return &rules[type];
}

<*
    Parses tokens by [precedence] and calls the appropriate function
    to compile the instructions based on said [precedence].

    @param precedence "The operator precedence to follow"
*>
fn void parse_precedence(Precedence precedence) @private
{
    advance();

    ParseFn prefix_rule = get_rule(parser.previous.type).prefix;
    if (prefix_rule == null)
    {
        error::@previous("Expected expression");
        return;
    }

    bool can_assign = precedence <= Precedence.ASSIGNMENT;
    prefix_rule(can_assign);

    while (precedence <= get_rule(parser.current.type).precedence)
    {
        advance();
        ParseFn infix_rule = get_rule(parser.previous.type).infix;
        infix_rule(can_assign);
    }

    if (can_assign && match(TokenType.EQUAL))
        { error::@previous("Invalid assignment target"); }
}

<*
    Add's an identifier for a variable declaration to the compiling chunk's
    constants pool.

    @param [&in] name "The literal name of the identifier"
*>
fn char identifier_constant(Token *name) @private
{
    return make_constant(obj_val(object::copy_string(name.lexeme, name.lexeme.len)));
}

<*
    Returns 'true' if the two given tokens have equivalent lexemes, otherwise it returns
    'false'.

    NOTE: In C, this is done by checking the lengths and using memcmp. In C3, that is not
    necessary. If you are working with the (String) type, you can directly compare for
    equality. This is how I handle keywords in the lexing stage as well.

    @param [&in] a "The first, or 'a' token to compare"
    @param [&in] b "The second, or 'b' token to compare"
*>
fn bool identifiers_equal(Token *a, Token *b) @private
{
    return a.lexeme == b.lexeme;
}

<*
    Takes in a reference to the current compiler and a token, and searches for the
    associated local variable, returning the index if found. Otherwise, it returns
    '-1'.

    @param [&in] compiler "A reference to the current compiler"
    @param [&in] name "A reference to the variable to search for"
*>
fn int resolve_local(Compiler *compiler, Token *name)
{
    for (int i = compiler.local_count - 1; i >= 0; i--)
    {
        Local *local = &compiler.locals[i];
        if (identifiers_equal(name, &local.name))
        {
            if (local.depth == -1)
            {
                error::@previous("Cannot read a local variable within its own initializer");
            }

            return i;
        }
    }

    return -1;
}

<*
    Returns the index of the upvalue if it already exists in the upvalue array
    of the [compiler]. If it is a new upvalue, it is added to that array and the
    index is returned. Otherwise, upon error, this function returns '0'.

    @param [&inout] compiler "A reference to the current compiler"
    @param index "The index of the local variable to be added as an upvalue"
    @param is_local "Flag to denote whether or not the variable is a local or an existing upvalue"
*>
fn int add_upvalue(Compiler *compiler, char index, bool is_local)
{
    int upvalue_count = compiler.function.upvalue_count;

    for (int i = 0; i < upvalue_count; i++)
    {
        Upvalue *upvalue = &compiler.upvalues[i];
        if (upvalue.index == index && upvalue.is_local == is_local)
            { return i; }
    }

    if (upvalue_count == UINT8_COUNT)
    {
        error::@previous("Too many closure variables in function");
        return 0;
    }

    compiler.upvalues[upvalue_count].is_local = is_local;
    compiler.upvalues[upvalue_count].index = index;
    return compiler.function.upvalue_count++;
}

<*
    Takes in a reference to the current [compiler] and a token, and searches
    for the associated local variable. If it is found, it is added to the array
    of upvalues held by the [compiler]. If it already exists in said array, the
    index is returned.

    Upon any issues, this function will return '-1'.

    @param [&inout] compiler "A reference to the current compiler"
    @param [&in] name "A reference to the token containing the name of the variable"
*>
fn int resolve_upvalue(Compiler *compiler, Token *name)
{
    if (compiler.enclosing == null) return -1;

    int local = resolve_local(compiler.enclosing, name);
    if (local != -1)
    {
        compiler.enclosing.locals[local].is_captured = true;
        return add_upvalue(compiler, to_byte(local), true);
    }

    int upvalue = resolve_upvalue(compiler.enclosing, name);
    if (upvalue != -1)
    {
        return add_upvalue(compiler, to_byte(upvalue), false);
    }

    return -1;
}

<*
    Add's a local to the current compilers array of locals.

    @param name "The token containing the name of the variable"
*>
fn void add_local(Token name) @private
{
    if (current.local_count == UINT8_COUNT)
    {
        error::@previous("Too many local variables in the current scope");
        return;
    }

    Local *local = &current.locals[current.local_count++];
    local.name = name;
    local.depth = -1;
    local.is_captured = false;
}

<*
    Check's the current depth of scope and if it is greater than 0, it passes
    the token on to be added to the current compilers array of locals.
*>
fn void declare_variable() @private
{
    if (current.scope_depth == 0) return;

    Token *name = &parser.previous;
    for (int i = current.local_count - 1; i >= 0; i--)
    {
        Local *local = &current.locals[i];
        if (local.depth != -1 && local.depth < current.scope_depth) break;

        if (identifiers_equal(name, &local.name))
        {
            error::@previous("Already a variable with this name in this scope");
        }
    }


    add_local(*name);
}

<*
    Consume's the identifier for a variable declaration and returns the index resulting
    from adding it to the constants pool.

    @param message "The error message in the event the next token is *not* an IDENTIFIER"
*>
fn char parse_variable(String message) @private
{
    consume(IDENTIFIER, message);

    declare_variable();
    if (current.scope_depth > 0) return 0;

    return identifier_constant(&parser.previous);
}

<*
    Marks a local variable as having been initialized.
*>
fn void mark_initialized() @private
{
    if (current.scope_depth == 0) return;

    current.locals[current.local_count - 1].depth = current.scope_depth;
}

<*
    After a variable declaration has been fully parsed (successfully), this
    function officially compiles the variable to signify it as being available
    for use.

    @param global "The index of the variable to compile"
*>
fn void define_variable(char global) @private
{
    if (current.scope_depth > 0)
    {
        mark_initialized();
        return;
    }

    emit_bytes(to_byte(OpCode.DEFINE_GLOBAL), global);
}

<*
    Compiles the list of arguments passed into a call expression.

    Returns the number of arguments that were compiled (max 255).
*>
fn char argument_list() @private
{
    char arg_count = 0;

    if (!check(RPAREN))
    {
        do {
            expression();
            if (arg_count == 255)
            {
                error::@previous("Cannot have more than 255 arguments to a call expression");
            }

            arg_count++;
        } while (match(COMMA));
    }

    consume(RPAREN, "Expected ')' after function call arguments");
    return arg_count;
}

<*
    Compiles an 'and' (aka '&&') expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void and(bool can_assign) @private
{
    int end_jump = emit_jump(to_byte(OpCode.JUMP_IF_FALSE));

    emit_byte(to_byte(OpCode.POP));
    parse_precedence(Precedence.AND);

    patch_jump(end_jump);
}

<*
    Compiles an 'or' (aka '||') expression.

    @param can_assign "Flag to denote when an expression is assignable"
*>
fn void or(bool can_assign) @private
{
    int else_jump = emit_jump(to_byte(OpCode.JUMP_IF_FALSE));
    int end_jump = emit_jump(to_byte(OpCode.JUMP));

    patch_jump(else_jump);
    emit_byte(to_byte(OpCode.POP));

    parse_precedence(Precedence.OR);
    patch_jump(end_jump);
}

<*
    Begins the compilation of an expression.
*>
fn void expression() @private
{
    parse_precedence(Precedence.ASSIGNMENT);
}

<*
    Compiles a statement. The simplest form of statement is the expression
    statement, which is any expression ended by a ';'.
*>
fn void statement() @private
{
    switch
    {
        case match(FOR):
            for_statement();

        case match(IF):
            if_statement();

        case match(PRINT):
            print_statement();

        case match(RETURN):
            return_statement();

        case match(WHILE):
            while_statement();

        case match(LBRACE):
        {
            begin_scope();
            block();
            end_scope();
        }

        default:
            expression_statement();
    }
}

<*
    Compile's a block statement, which is any number of statements found
    inbetween two curly braces.
*>
fn void block() @private
{
    while (!check(RBRACE) && !check(EOF))
        { declaration(); }

    consume(RBRACE, "Expected '}' after block");
}

<*
    Compiles an expression statement.

    An expression statement is any expression followed by a ';'.
*>
fn void expression_statement() @private
{
    expression();
    consume(SEMICOLON, "Expected ';' after expression");
    emit_byte(to_byte(OpCode.POP));
}

<*
    Compiles a for statement.
*>
fn void for_statement() @private
{
    begin_scope();
    consume(LPAREN, "Expected '(' after 'for'");

    if (match(SEMICOLON))
        { /* No initializer */ }
    else if (match(VAR))
        { var_declaration(); }
    else
        { expression_statement(); }

    int loop_start = current_chunk().count;
    int exit_jump = -1;

    if (!match(TokenType.SEMICOLON))
    {
        expression();
        consume(SEMICOLON, "Expected ';' after 'for' loop condition");

        // Jump out of the loop if the condition is false
        exit_jump = emit_jump(to_byte(OpCode.JUMP_IF_FALSE));
        emit_byte(to_byte(OpCode.POP));
    }

    if (!match(TokenType.RPAREN))
    {
        int body_jump = emit_jump(to_byte(OpCode.JUMP));
        int increment_start = current_chunk().count;

        expression();
        emit_byte(to_byte(OpCode.POP));
        consume(RPAREN, "Expected ')' after 'for' loop clauses");

        emit_loop(loop_start);
        loop_start = increment_start;
        patch_jump(body_jump);
    }

    statement();
    emit_loop(loop_start);

    if (exit_jump != -1)
    {
        patch_jump(exit_jump);
        emit_byte(to_byte(OpCode.POP));
    }

    end_scope();
}

<*
    Finishes the compilation of a function statement.

    This begins the chain of compilers. The top-level compiler
    is declared and initialized inside of 'compile()'.

    Each subsequent function contained within the implicit 'main'
    function gets its own separate compiler.
*>
fn void function(FunctionType type) @private
{
    Compiler compiler;
    init(&compiler, type);
    begin_scope();

    consume(LPAREN, "Expected '(' after function name");
    if (!check(RPAREN))
    {
        do {
            current.function.arity++;
            if (current.function.arity > char.max)
            {
                error::@current("Cannot have more than 255 parameters to a function");
            }

            char constant = parse_variable("Expected parameter name");
            define_variable(constant);
        } while (match(COMMA));
    }
    consume(RPAREN, "Expected ')' after function parameters");

    consume(LBRACE, "Expected '{' before function body");
    block();

    ObjFunction *function = end_compiler();
    emit_bytes(to_byte(OpCode.CLOSURE), make_constant(obj_val(function)));

    for (int i = 0; i < function.upvalue_count; i++)
    {
        emit_byte(compiler.upvalues[i].is_local ? 1 : 0);
        emit_byte((char)compiler.upvalues[i].index);
    }
}

<*
    Compiles an 'if-else' statement.
*>
fn void if_statement() @private
{
    consume(LPAREN, "Expected '(' after 'if'");
    expression();
    consume(RPAREN, "Expected ')' after 'if' condition");

    int then_jump = emit_jump(to_byte(OpCode.JUMP_IF_FALSE));
    emit_byte(to_byte(OpCode.POP));
    statement();

    int else_jump = emit_jump(to_byte(OpCode.JUMP));
    patch_jump(then_jump);
    emit_byte(to_byte(OpCode.POP));

    if (match(ELSE)) statement();
    patch_jump(else_jump);
}

<*
    Compiles a 'print' statement.

    In Lox, 'print' is a keyword and not a builtin function.
*>
fn void print_statement() @private
{
    expression();
    consume(SEMICOLON, "Expected ';' after 'print' value");
    emit_byte(to_byte(OpCode.PRINT));
}

<*
    Compiles a return statement.
*>
fn void return_statement() @private
{
    if (current.type == FunctionType.SCRIPT)
    {
        error::@previous("Cannot return from top-level code");
    }

    if (match(SEMICOLON))
    {
        emit_return();
    }
    else
    {
        expression();
        consume(SEMICOLON, "Expected ';' after 'return' value");
        emit_byte(to_byte(OpCode.RETURN));
    }
}

<*
    Compiles a 'while' statement.

    As with other languages, this runs code on a loop 'while'
    a certain condition is truthy.
*>
fn void while_statement() @private
{
    int loop_start = current_chunk().count;

    consume(LPAREN, "Expected '(' after 'while'");
    expression();
    consume(RPAREN, "Expected ')' after 'while' condition");

    int exit_jump = emit_jump(to_byte(OpCode.JUMP_IF_FALSE));
    emit_byte(to_byte(OpCode.POP));
    statement();

    emit_loop(loop_start);

    patch_jump(exit_jump);
    emit_byte(to_byte(OpCode.POP));
}

<*
    Compiles a declaration-type statement. Examples include variables,
    functions, etc.
*>
fn void declaration() @private
{
    switch
    {
        case match(TokenType.FUN):
            fun_declaration();
        case match(TokenType.VAR):
            var_declaration();
        default:
            statement();
    }

    if (parser.panic_mode) synchronize();
}

<*
    Compiles a function declaration statement.
*>
fn void fun_declaration() @private
{
    char global = parse_variable("Expected function name");
    mark_initialized();
    function(FunctionType.FUNCTION);
    define_variable(global);
}

<*
    Compiles a variable declaration statement.
*>
fn void var_declaration() @private
{
    char global = parse_variable("Expected variable name");

    if (match(TokenType.EQUAL))
    {
        expression();
    }
    else
    {
        emit_byte(to_byte(OpCode.NIL));
    }

    consume(SEMICOLON, "Expected ';' after variable declaration");

    define_variable(global);
}

<*
    Synchronizes the compiler in the event of a panic-causing error occurring.
    This is triggered when 'parser.panic_mode' is set to 'true'.
*>
fn void synchronize() @private
{
    parser.panic_mode = false;

    while (parser.current.type != TokenType.EOF)
    {
        if (parser.previous.type == TokenType.SEMICOLON) return;
        switch (parser.current.type)
        {
            case TokenType.CLASS:
            case TokenType.FOR:
            case TokenType.FUN:
            case TokenType.IF:
            case TokenType.PRINT:
            case TokenType.RETURN:
            case TokenType.VAR:
            case TokenType.WHILE:
                return;
            default:
                ; // Do nothing
        }
    }
}

<*
    Compiles a Lox source file into Lox bytecode.

    @param [&in] source "The source code of the script being compiled"
*>
fn ObjFunction *compile(char *source)
{
    $if $feature(DEBUG) &&& (DUMP_TOKENS == true):
        lexer::dump_tokens(source);
        return null;
    $endif

    lexer::init(source);

    Compiler compiler;
    init(&compiler, FunctionType.SCRIPT);

    parser.had_error = false;
    parser.panic_mode = false;

    advance();
    while (!match(TokenType.EOF))
    {
        declaration();
    }

    ObjFunction *function = end_compiler();
    return parser.had_error ? null : function;
}

<*
    Marks every source of roots found within the compiler chain.
*>
fn void mark_compiler_roots()
{
    Compiler *compiler = current;
    while (compiler != null)
    {
        memory::mark_object((Obj *)compiler.function);
        compiler = compiler.enclosing;
    }
}
