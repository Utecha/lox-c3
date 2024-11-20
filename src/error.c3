module lox::error;
import lox::compiler;
import lox::lexer;
import lox::object;
import lox::vm @public;
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

<*
    Reports an error at runtime. This is called within the VM itself only.

    As of the addition of call frames and functions, this now prints appropriate
    stack traces.

    @param fmt "The string to format"
    @param args "The arguments to format into the format string"
*>
fn void runtime(String fmt, args...)
{
    io::eprintf("Runtime Error: ");
    io::eprintfn(fmt, ...args);

    for (int i = vm.frame_count - 1; i >= 0; i--)
    {
        CallFrame *frame = &vm.frames[i];
        ObjFunction *function = frame.function;
        int instruction = (int)(frame.ip - frame.function.chunk.code - 1);

        io::eprintf("[line %d] in ", function.chunk.get_line(instruction));
        if (function.name == null)
            { io::eprintfn("script"); }
        else
            { io::eprintfn("%s()", (ZString)function.name.chars); }
    }

    vm::reset_stack();
}
