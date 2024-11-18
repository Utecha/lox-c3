module lox::compiler;
import lox::chunk;
import lox::common;
import lox::error;
import lox::lexer;
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
def ParseFn = fn void ();

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
    [TokenType.LPAREN]      = { &grouping,  null,       Precedence.NONE },
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
    [TokenType.IDENTIFIER]  = { null,       null,       Precedence.NONE },
    [TokenType.NUMBER]      = { &number,    null,       Precedence.NONE },
    [TokenType.STRING]      = { null,       null,       Precedence.NONE },
    [TokenType.AND]         = { null,       null,       Precedence.NONE },
    [TokenType.CLASS]       = { null,       null,       Precedence.NONE },
    [TokenType.ELSE]        = { null,       null,       Precedence.NONE },
    [TokenType.FALSE]       = { &literal,   null,       Precedence.NONE },
    [TokenType.FOR]         = { null,       null,       Precedence.NONE },
    [TokenType.FUN]         = { null,       null,       Precedence.NONE },
    [TokenType.IF]          = { null,       null,       Precedence.NONE },
    [TokenType.NIL]         = { &literal,   null,       Precedence.NONE },
    [TokenType.OR]          = { null,       null,       Precedence.NONE },
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

//===----------------===//
//      Compiler
//===----------------===//

/* Temporary global bytecode (Chunk) */
Chunk *compiling;

<*
    Return's the pointer to the current [compiling] chunk of bytecode.

    @ensure compiling != null
*>
fn Chunk *current_chunk() @private
{
    return compiling;
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
    emit_byte(to_byte(OpCode.RETURN));
}

<*
    Ends compilation of the users source code.
*>
fn void end_compiler() @private
{
    emit_return();

    $if $feature(DEBUG) &&& DUMP_CHUNK:
        if (!parser.had_error)
            { current_chunk().disassemble("Code"); }
    $endif
}

<*
    Compiles a conditional (also known as ternary) (?:) expression.
*>
fn void ternary() @private
{
    parse_precedence(Precedence.TERNARY);
    consume(TokenType.COLON, "Expected ':' between ternary 'true' and 'false' branches");
    parse_precedence(Precedence.TERNARY);
    emit_byte(to_byte(OpCode.TERNARY));
}

<*
    Compiles a binary expression.
*>
fn void binary() @private
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
    Compiles a literal expression, such as 'nil', 'true', or 'false'.
*>
fn void literal() @private
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
*>
fn void grouping() @private
{
    expression();
    consume(TokenType.RPAREN, "Expected ')' after expression");
}

<*
    Compiles a number literal [value].
*>
fn void number() @private
{
    double! value = parser.previous.lexeme.to_double();
    if (catch value) return;

    emit_constant(number_val(value));
}

<*
    Compiles a unary (!, -) expression.
*>
fn void unary() @private
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

fn ParseRule *get_rule(TokenType type) @private
{
    return &rules[type];
}

<*
    Parses tokens by [precedence] and calls the appropriate function
    to compile the instructions based on said [precedence].
*>
fn void parse_precedence(Precedence precedence)
{
    advance();

    ParseFn prefix_rule = get_rule(parser.previous.type).prefix;
    if (prefix_rule == null)
    {
        error::@previous("Expected expression");
        return;
    }

    prefix_rule();

    while (precedence <= get_rule(parser.current.type).precedence)
    {
        advance();
        ParseFn infix_rule = get_rule(parser.previous.type).infix;
        infix_rule();
    }
}

<*
    Begins the compilation of an expression.
*>
fn void expression() @private
{
    parse_precedence(Precedence.ASSIGNMENT);
}

<*
    Compiles a Lox source file into Lox bytecode.

    @param [&in] source "The source code of the script being compiled"
    @param [&inout] chunk "The bytecode chunk to compile into"
*>
fn bool compile(char *source, Chunk *chunk)
{
    $if $feature(DEBUG) &&& (DUMP_TOKENS == true):
        lexer::dump_tokens(source);
        return true;
    $endif

    lexer::init(source);
    compiling = chunk;

    parser.had_error = false;
    parser.panic_mode = false;

    advance();
    expression();
    consume(TokenType.EOF, "Expected end of expression");
    end_compiler();

    return !parser.had_error;
}
