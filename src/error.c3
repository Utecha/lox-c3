module lox::error;
import lox::compiler;
import lox::lexer;
import lox::vm;
import std::io @norecurse;

//===----------------------===//
//   Compile Error Reporting
//===----------------------===//

<*
    Reports the given error [message] resulting from an offending [token].

    @param [&in] token "The offending token"
    @param message "The error message to report"
*>
fn void error_at(Token *token, String message)
{
    if (parser.panic_mode) return;
    parser.panic_mode = true;

    io::eprintf("[line %d] Error", token.line);

    switch (token.type)
    {
        case ERROR: break;
        case EOF:   io::eprintf(" at end");
        default:    io::eprintf(" at '%s'", token.lexeme);
    }

    io::eprintfn(": %s", message);
    parser.had_error = true;
}

<*
    Wrapper for 'error_at()' that passes on the given [message] and provides
    the function with the [current] token.

    @param message "The error message to report"
*>
macro @current(String message)
{
    error_at(&parser.current, message);
}

<*
    Wrapper for 'error_at()' that passes on the given [message] and provides
    the function with the [previous] token.

    @param message "The error message to report"
*>
macro @previous(String message)
{
    error_at(&parser.previous, message);
}

//===----------------------===//
//   Runtime Error Reporting
//===----------------------===//


