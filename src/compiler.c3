module lox::compiler;
import lox::lexer;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Compiler
//===----------------------------------------------------------------------===//

fn void compile(char *source)
{
    lexer::init(source);

    int line = -1;
    for (;;)
    {
        Token token = lexer::get_token();
        if (line != token.line)
        {
            io::printf("%4d ", token.line);
            line = token.line;
        }
        else
        {
            io::print("   | ");
        }

        io::printfn("%-12s '%s'", token.type, token.lexeme);
        if (token.type == EOF) break;
    }
}