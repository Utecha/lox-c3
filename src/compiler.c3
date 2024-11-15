module lox::compiler;
import lox::common;
import lox::lexer;
import std::io @norecurse;

<*
    Compiles a Lox source file into Lox bytecode.

    @param [in] source "The source code of the script being compiled"
*>
fn void compile(char *source)
{
    $if $feature(DEBUG) && DUMP_TOKENS:
        lexer::dump_tokens(source);
    $endif
}
