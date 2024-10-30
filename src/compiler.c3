module lox::compiler;
import lox::chunk;
import lox::common;
import lox::lexer;
import lox::value;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Parser
//===----------------------------------------------------------------------===//

struct Parser
{
    Token current;
    Token previous;
    bool had_error;
    bool panic_mode;
}

enum Precedence : int
{
    NONE,
    ASSIGNMENT,     // =
    CONDITIONAL,    // ?:
    OR,             // or
    AND,            // and
    EQUALITY,       // == !=
    COMPARISON,     // < > <= >=
    TERM,           // - +
    FACTOR,         // / *
    UNARY,          // ! -
    CALL,           // . ()
    PRIMARY
}

def ParseFn = fn void () @private;

struct ParseRule
{
    ParseFn prefix;
    ParseFn infix;
    Precedence precedence;
}

Parser parser @private;

fn void error_at(Token *token, String message) @private
{
    if (parser.panic_mode) return;
    parser.panic_mode = true;

    io::eprintf("[line %d] Error", token.line);
    switch (token.type)
    {
        case ERROR: break;
        case EOF: io::eprint(" at end");
        default: io::eprintf(" at '%s'", token.lexeme);
    }

    io::eprintfn(": %s", message);
    parser.had_error = true;
}

fn void error(String message) @private
{
    error_at(&parser.previous, message);
}

fn void error_at_current(String message) @private
{
    error_at(&parser.current, message);
}

fn void advance() @private
{
    parser.previous = parser.current;
    for (;;)
    {
        parser.current = lexer::get_token();
        if (parser.current.type != ERROR) break;

        error_at_current(parser.current.lexeme);
    }
}

fn void consume(TokenType type, String message) @private
{
    if (parser.current.type == type)
    {
        advance();
        return;
    }

    error_at_current(message);
}

//===----------------------------------------------------------------------===//
// Lox | Compiler
//===----------------------------------------------------------------------===//

Chunk *compiling @private = null;

fn Chunk *current_chunk() @private
{
    return compiling;
}

fn void emit_opcode(OpCode code) @private
{
    current_chunk().write_opcode(code, parser.previous.line);
}

fn void emit_opcodes(OpCode a, OpCode b) @private
{
    emit_opcode(a);
    emit_opcode(b);
}

fn void emit_byte(int byte) @private
{
    current_chunk().write_byte(byte, parser.previous.line);
}

fn void emit_bytes(OpCode code, int byte) @private
{
    emit_opcode(code);
    emit_byte(byte);
}

fn void emit_return() @private
{
    emit_opcode(RETURN);
}

fn void emit_constant(Value value) @private
{
    current_chunk().write_constant(value, parser.previous.line);
}

fn void end_compiler() @private
{
    emit_return();

    $if (DUMP_CHUNK):
        if (!parser.had_error)
            { current_chunk().disassemble("Code"); }
    $endif
}

fn void ternary() @private
{
    parse_precedence(CONDITIONAL);
    consume(COLON, "Expected ':' between ternary 'true' and 'false' branches");
    parse_precedence(CONDITIONAL);
    emit_opcode(TERNARY);
}

fn void binary() @private
{
    TokenType op_type = parser.previous.type;
    ParseRule *rule = get_rule(op_type);
    parse_precedence(rule.precedence + 1);

    switch (op_type)
    {
        case ISEQ:      emit_opcode(EQUAL);
        case NOTEQ:     emit_opcodes(EQUAL, NOT);
        case GT:        emit_opcode(GREATER);
        case GTEQ:      emit_opcodes(LESS, NOT);
        case LT:        emit_opcode(LESS);
        case LTEQ:      emit_opcodes(GREATER, NOT);
        case MINUS:     emit_opcode(SUBTRACT);
        case PLUS:      emit_opcode(ADD);
        case SLASH:     emit_opcode(DIVIDE);
        case STAR:      emit_opcode(MULTIPLY);
        default:        unreachable();
    }
}

fn void literal() @private
{
    switch (parser.previous.type)
    {
        case FALSE: emit_opcode(FALSE);
        case NIL:   emit_opcode(NIL);
        case TRUE:  emit_opcode(TRUE);
        default:    unreachable();
    }
}

fn void grouping() @private
{
    expression();
    consume(RPAREN, "Expected ')' after expression");
}

fn void number() @private
{
    double! value = parser.previous.lexeme.to_double();
    if (catch value)
    {
        error("Invalid number literal");
        return;
    }

    emit_constant(number_val(value));
}

fn void unary() @private
{
    TokenType op_type = parser.previous.type;

    // Compile the operand
    parse_precedence(UNARY);

    // Emit the operator instruction
    switch (op_type)
    {
        case NOT:   emit_opcode(NOT);
        case MINUS: emit_opcode(NEGATE);
        default:    unreachable();
    }
}

ParseRule[*] rules = {
    [TokenType.ERROR]       = { null,       null,       NONE },
    [TokenType.EOF]         = { null,       null,       NONE },
    [TokenType.LPAREN]      = { &grouping,  null,       NONE },
    [TokenType.RPAREN]      = { null,       null,       NONE },
    [TokenType.LBRACE]      = { null,       null,       NONE },
    [TokenType.RBRACE]      = { null,       null,       NONE },
    [TokenType.COMMA]       = { null,       null,       NONE },
    [TokenType.DOT]         = { null,       null,       NONE },
    [TokenType.SEMICOLON]   = { null,       null,       NONE },
    [TokenType.EQUAL]       = { null,       null,       NONE },
    [TokenType.QMARK]       = { null,       &ternary,   CONDITIONAL },
    [TokenType.COLON]       = { null,       null,       NONE },
    [TokenType.ISEQ]        = { null,       &binary,    EQUALITY },
    [TokenType.NOTEQ]       = { null,       &binary,    EQUALITY },
    [TokenType.GT]          = { null,       &binary,    COMPARISON },
    [TokenType.GTEQ]        = { null,       &binary,    COMPARISON },
    [TokenType.LT]          = { null,       &binary,    COMPARISON },
    [TokenType.LTEQ]        = { null,       &binary,    COMPARISON },
    [TokenType.MINUS]       = { &unary,     &binary,    TERM },
    [TokenType.PLUS]        = { null,       &binary,    TERM },
    [TokenType.SLASH]       = { null,       &binary,    FACTOR },
    [TokenType.STAR]        = { null,       &binary,    FACTOR },
    [TokenType.NOT]         = { &unary,     null,       NONE },
    [TokenType.IDENTIFIER]  = { null,       null,       NONE },
    [TokenType.NUMBER]      = { &number,    null,       NONE },
    [TokenType.STRING]      = { null,       null,       NONE },
    [TokenType.AND]         = { null,       null,       NONE },
    [TokenType.CLASS]       = { null,       null,       NONE },
    [TokenType.ELSE]        = { null,       null,       NONE },
    [TokenType.FALSE]       = { &literal,   null,       NONE },
    [TokenType.FOR]         = { null,       null,       NONE },
    [TokenType.FUN]         = { null,       null,       NONE },
    [TokenType.IF]          = { null,       null,       NONE },
    [TokenType.NIL]         = { &literal,   null,       NONE },
    [TokenType.OR]          = { null,       null,       NONE },
    [TokenType.PRINT]       = { null,       null,       NONE },
    [TokenType.RETURN]      = { null,       null,       NONE },
    [TokenType.SUPER]       = { null,       null,       NONE },
    [TokenType.THIS]        = { null,       null,       NONE },
    [TokenType.TRUE]        = { &literal,   null,       NONE },
    [TokenType.VAR]         = { null,       null,       NONE },
    [TokenType.WHILE]       = { null,       null,       NONE },
};

fn ParseRule *get_rule(TokenType type)
{
    return &rules[type];
}

fn void parse_precedence(Precedence precedence)
{
    advance();
    ParseFn prefix_rule = get_rule(parser.previous.type).prefix;
    if (prefix_rule == null)
    {
        error("Expected expression");
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

fn void expression() @private
{
    parse_precedence(ASSIGNMENT);
}

fn bool compile(char *source, Chunk *chunk)
{
    lexer::init(source);
    compiling = chunk;

    parser.had_error = false;
    parser.panic_mode = false;

    advance();
    expression();
    consume(EOF, "Expected end of expression");
    end_compiler();

    return !parser.had_error;
}
