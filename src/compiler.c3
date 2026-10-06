module lox::compiler;
import lox::debug;
import lox::lexer;
import lox::token;

//------------------------------------------------------------------------------

fn void compile(LoxVM *vm, char *source)
{
    LoxLexer l;
    lexer::init(&l, source);

    $if $feat(DEBUG) &&& debug::DUMP_TOKENS:
        debug::dump_tokens(&l);
        lexer::init(&l, source); // Reset for reuse.
    $endif
}
